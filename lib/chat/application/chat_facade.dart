import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../features/auth/domain/ai_provider_detector.dart';
import '../../api/ai_chat_client.dart';
import '../../api/openrouter_api_client.dart';
import '../../api/vsegpt_api_client.dart';
import '../../models/message.dart';

import '../data/model_selection_store.dart';
import '../domain/services/token_budget.dart';
import '../domain/services/context_builder.dart';
import '../domain/services/cost_calculator.dart';

class ChatFacade {
  final TokenBudget tokenBudget;
  final ContextBuilder contextBuilder;
  final CostCalculator costCalculator;
  final ModelSelectionStore modelStore;

  const ChatFacade({
    required this.tokenBudget,
    required this.contextBuilder,
    required this.costCalculator,
    required this.modelStore,
  });

  AiChatClient createClient({
    required AiProviderType providerType,
    required Uri baseUri,
    required String apiKey,
  }) {
    return switch (providerType) {
      AiProviderType.openRouter =>
        OpenRouterApiClient(baseUri: baseUri, apiKey: apiKey),
      AiProviderType.vseGpt =>
        VseGptApiClient(baseUri: baseUri, apiKey: apiKey),
    };
  }

  int envPaidDefaultMaxTokens() =>
      int.tryParse(dotenv.env['MAX_TOKENS'] ?? '') ?? 1000;

  int envFreeHardCap() {
    final v = int.tryParse(dotenv.env['MAX_TOKENS_FREE'] ?? '');
    return (v != null && v > 0) ? v : 8192;
  }

  /// Получает температуру из переменных окружения с безопасным парсингом
  /// Если значение некорректное или отсутствует, возвращает значение по умолчанию 0.7
  double envTemperature() {
    final tempStr = dotenv.env['TEMPERATURE'] ?? '0.7';
    // Безопасный парсинг с обработкой ошибок
    return double.tryParse(tempStr.trim()) ?? 0.7;
  }

  bool envStreamEnabled() =>
      (dotenv.env['STREAM'] ?? 'false').toLowerCase() == 'true';

  int envTimeoutSec() =>
      (int.tryParse(dotenv.env['REQUEST_TIMEOUT_SEC'] ?? '') ?? 120)
          .clamp(60, 600);

  /// Унифицированный расчёт maxTokens (и для paid, и для free) с учётом contextLen.
  int computeMaxTokens({
    required String promptText,
    required int? contextLen,
    required bool isFree,
  }) {
    final desired = envPaidDefaultMaxTokens();
    final hardCap = isFree ? envFreeHardCap() : desired;
    return tokenBudget.maxCompletionTokens(
      promptText: promptText,
      desired: desired,
      hardCap: hardCap,
      contextLen: contextLen,
    );
  }

  /// Для regenerate: строим prompt так, чтобы он точно влез в prompt budget.
  /// promptBudget = contextLen - reserve - completionTokens
  String buildRegeneratePromptMiddleOut({
    required List<ChatMessage> allMessages,
    required String targetTurnId,
    required int contextLen,
    required int completionTokens,
  }) {
    final promptBudget = tokenBudget.maxPromptTokens(
      contextLen: contextLen,
      completionTokens: completionTokens,
    );

    return contextBuilder.buildPseudoChatPromptMiddleOut(
      allMessages: allMessages,
      targetTurnId: targetTurnId,
      maxPromptTokens: promptBudget,
    );
  }

  /// Если после middle-out prompt всё равно слишком большой,
  /// можно мягко уменьшить completionTokens.
  int adjustCompletionForPrompt({
    required String prompt,
    required int contextLen,
    required int completionTokens,
  }) {
    final promptTok = tokenBudget.estimateTokensRough(prompt);
    final allowed = contextLen - tokenBudget.reserveTokens - promptTok;
    if (allowed <= tokenBudget.minCompletionTokens) {
      return tokenBudget.minCompletionTokens;
    }
    return math.min(completionTokens, allowed);
  }
}
