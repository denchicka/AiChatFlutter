import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../models/message.dart';

class ChatExportService {
  Future<String> exportLogs({
    required List<String> debugLogs,
    required List<ChatMessage> messages,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final name =
        'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';
    final file = File('${dir.path}/$name');

    final b = StringBuffer();
    b.writeln('=== Debug Logs ===\n');
    for (final l in debugLogs) {
      b.writeln(l);
    }

    b.writeln('\n=== Chat Logs ===\n');
    b.writeln('Generated: ${now.toString()}\n');

    for (final m in messages) {
      b.writeln('${m.isUser ? "User" : "AI"} (${m.modelId}):');
      b.writeln(m.content);
      if (m.tokens != null) b.writeln('Tokens: ${m.tokens}');
      b.writeln('Time: ${m.timestamp}');
      b.writeln('---\n');
    }

    await file.writeAsString(b.toString());
    return file.path;
  }

  Future<String> exportMessagesAsJson({
    required List<ChatMessage> messages,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final name =
        'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';
    final file = File('${dir.path}/$name');

    final list = messages.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(list));
    return file.path;
  }
}
