import 'dart:math' as math;
import '../../../models/message.dart';
import 'token_budget.dart';

class ContextBuilder {
  final TokenBudget budget;

  const ContextBuilder({required this.budget});

  List<ChatMessage> buildContextUpToTurn({
    required List<ChatMessage> allMessages,
    required String targetTurnId,
  }) {
    final userByTurn = <String, ChatMessage>{};
    final activeAiByTurn = <String, ChatMessage>{};

    for (final m in allMessages) {
      if (m.isUser) {
        userByTurn.putIfAbsent(m.turnId, () => m);
      } else {
        final txt = m.content.trim();
        if (txt.isEmpty || txt == '…') continue;
        if (m.isActiveVariant) {
          activeAiByTurn[m.turnId] = m;
        }
      }
    }

    final turns = userByTurn.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final out = <ChatMessage>[];
    for (final userMsg in turns) {
      out.add(userMsg);

      // на targetTurnId — останавливаемся (как у тебя)
      if (userMsg.turnId == targetTurnId) break;

      final ai = activeAiByTurn[userMsg.turnId];
      if (ai != null) out.add(ai);
    }
    return out;
  }

  String buildPseudoChatPrompt(
    List<ChatMessage> ctx, {
    String systemLine = 'Продолжи диалог и ответь как ассистент.',
  }) {
    final b = StringBuffer();
    b.writeln(systemLine);
    b.writeln('');

    for (final m in ctx) {
      final role = m.isUser ? 'User' : 'Assistant';
      b.writeln('$role: ${m.content}');
      b.writeln('');
    }

    b.write('Assistant:');
    return b.toString();
  }

  /// Middle-out: берём начало + конец, выкидываем середину, пока не влезем.
  String buildPseudoChatPromptMiddleOut({
    required List<ChatMessage> allMessages,
    required String targetTurnId,
    required int maxPromptTokens,
    String systemLine = 'Продолжи диалог и ответь как ассистент.',
    int headTurns = 2,
    int tailTurns = 6,
  }) {
    // 1) превращаем историю в “turn blocks” (user + optional ai)
    final ctx = buildContextUpToTurn(
      allMessages: allMessages,
      targetTurnId: targetTurnId,
    );

    // собираем блоки: [User,(Assistant?)] по порядку
    final blocks = <List<ChatMessage>>[];
    for (int i = 0; i < ctx.length; i++) {
      final m = ctx[i];
      if (!m.isUser) continue;

      final block = <ChatMessage>[m];

      // если следующий есть и он assistant — добавим (это не targetTurn)
      if (i + 1 < ctx.length && !ctx[i + 1].isUser) {
        block.add(ctx[i + 1]);
      }
      blocks.add(block);
    }

    // helper
    String buildFromBlocks(List<List<ChatMessage>> bs) {
      final flat = <ChatMessage>[];
      for (final b in bs) {
        flat.addAll(b);
      }
      return buildPseudoChatPrompt(flat, systemLine: systemLine);
    }

    // 2) если и так влезает — возвращаем
    var prompt = buildPseudoChatPrompt(ctx, systemLine: systemLine);
    if (budget.estimateTokensRough(prompt) <= maxPromptTokens) return prompt;

    // 3) middle-out: уменьшаем “tail”, потом “head”
    int head = math.min(headTurns, blocks.length);
    int tail = math.min(tailTurns, math.max(0, blocks.length - head));

    List<List<ChatMessage>> select() {
      if (blocks.isEmpty) return const [];
      if (blocks.length <= head + tail) return blocks;

      final h = blocks.take(head).toList();
      final t = blocks.skip(blocks.length - tail).toList();
      return [...h, ...t];
    }

    while (true) {
      final selected = select();
      prompt = buildFromBlocks(selected);

      if (budget.estimateTokensRough(prompt) <= maxPromptTokens) return prompt;

      // если уже почти нечего сжимать — fallback до минимального (последний user)
      if (head <= 1 && tail <= 1) {
        final lastUserBlock =
            blocks.isNotEmpty ? [blocks.last] : <List<ChatMessage>>[];
        return buildFromBlocks(lastUserBlock);
      }

      // режем tail приоритетно (обычно именно “хвост” разрастается)
      if (tail > 1) {
        tail--;
      } else if (head > 1) {
        head--;
      } else {
        // крайний случай
        return buildFromBlocks([blocks.last]);
      }
    }
  }
}
