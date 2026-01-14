// VseGptApiClient - реализация AiChatClient для VseGPT.ru
//
// Ответственность:
// - Получение списка доступных моделей через VseGPT API
// - Отправка сообщений (non-streaming и streaming)
// - Парсинг ответов API в унифицированный формат
//
// Особенности VseGPT:
// - Цены указываются за 1000 токенов (более крупные числа, например 0.5)
// - Поддерживает streaming через SSE
// - API совместим с OpenAI форматом
// - Баланс в рублях
//
// API endpoints:
// - GET /models - список доступных моделей
// - POST /chat/completions - отправка сообщения (non-streaming)
// - POST /chat/completions (stream: true) - отправка сообщения (streaming)
//
// Примечание:
// - Базовый URL обычно: https://api.vsegpt.ru:6070/v1
// - Может отличаться в зависимости от настроек пользователя

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_chat_client.dart';

/// Реализация AiChatClient для VseGPT.ru
class VseGptApiClient implements AiChatClient {
  final Uri baseUri; // например https://api.vsegpt.ru:6070/v1
  final String apiKey;

  VseGptApiClient({
    required this.baseUri,
    required this.apiKey,
  });

  @override
  Future<List<AiModelInfo>> getModels() async {
    final headers = buildHeaders(apiKey);
    final uri = baseUri.replace(path: joinPath(baseUri.path, 'models'));
    final http.Response res = await safeGet(uri, headers);

    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return [];

    final models = <AiModelInfo>[];
    for (final item in data) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final name = (m['name'] ?? m['title'] ?? id).toString();

      double prompt = double.nan;
      double completion = double.nan;
      if (m['pricing'] is Map) {
        final pricing = Map<String, dynamic>.from(m['pricing']);
        prompt =
            double.tryParse(pricing['prompt']?.toString() ?? '') ?? double.nan;
        completion = double.tryParse(pricing['completion']?.toString() ?? '') ??
            double.nan;
      }

      final ctx =
          (m['context_length'] ?? m['max_context_length'] ?? 0).toString();
      final contextLength = int.tryParse(ctx) ?? 0;

      models.add(
        AiModelInfo(
          id: id,
          name: name,
          promptPrice: prompt,
          completionPrice: completion,
          contextLength: contextLength,
        ),
      );
    }

    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String modelId,
    required int maxTokens,
    required double temperature,
    CancelToken? cancelToken,
  }) async {
    final headers = buildHeaders(apiKey);
    final uri =
        baseUri.replace(path: joinPath(baseUri.path, 'chat/completions'));

    final body = {
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': message}
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': false,
    };

    try {
      final http.Response res =
          await safePost(uri, headers, body, cancelToken: cancelToken);

      Map<String, dynamic>? decoded;
      try {
        final text = utf8.decode(res.bodyBytes);
        final obj = jsonDecode(text);
        if (obj is Map<String, dynamic>) decoded = obj;
      } catch (_) {
        return {'error': 'Некорректный ответ сервера (HTTP ${res.statusCode})'};
      }

      if (res.statusCode == 200 && decoded != null) return decoded;

      final msg = decoded?['error']?['message']?.toString() ??
          decoded?['message']?.toString() ??
          'HTTP ${res.statusCode}';

      return {'error': msg};
    } on http.ClientException catch (_) {
      if (cancelToken?.isCancelled == true) return {'error': 'cancelled'};
      rethrow;
    } on SocketException catch (_) {
      if (cancelToken?.isCancelled == true) return {'error': 'cancelled'};
      rethrow;
    }
  }

  @override
  Stream<Map<String, dynamic>> streamMessage({
    required String message,
    required String modelId,
    required int maxTokens,
    required double temperature,
    CancelToken? cancelToken,
  }) async* {
    final headers = buildHeaders(apiKey);
    final uri =
        baseUri.replace(path: joinPath(baseUri.path, 'chat/completions'));

    final body = {
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': message}
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': true,
    };

    final client = http.Client();
    cancelToken?.whenCancel.then((_) {
      try {
        client.close();
      } catch (_) {}
    });

    try {
      final req = http.Request('POST', uri);
      req.headers.addAll(headers);
      req.body = jsonEncode(body);

      final res = await client.send(req);

      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('text/event-stream')) {
        final text = await res.stream.bytesToString();
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            yield decoded;
            return;
          }
          yield {'error': 'Invalid JSON response'};
        } catch (_) {
          yield {'error': 'Некорректный ответ сервера'};
        }
        return;
      }

      await for (final event in decodeSseToJson(res.stream)) {
        yield event;
      }
    } on http.ClientException catch (_) {
      if (cancelToken?.isCancelled == true) {
        yield {'error': 'cancelled'};
        return;
      }
      rethrow;
    } on SocketException catch (_) {
      if (cancelToken?.isCancelled == true) {
        yield {'error': 'cancelled'};
        return;
      }
      rethrow;
    } finally {
      try {
        client.close();
      } catch (_) {}
    }
  }
}
