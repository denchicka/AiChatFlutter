// OpenRouterApiClient - реализация AiChatClient для OpenRouter.ai
//
// Ответственность:
// - Получение списка доступных моделей через OpenRouter API
// - Отправка сообщений (non-streaming и streaming)
// - Парсинг ответов API в унифицированный формат
//
// Особенности OpenRouter:
// - Цены указываются за токен (очень маленькие числа, например 0.00001)
// - Поддерживает streaming через SSE
// - Единый API для доступа к моделям разных провайдеров
// - Баланс в долларах
//
// API endpoints:
// - GET /models/user - список доступных моделей
// - POST /chat/completions - отправка сообщения (non-streaming)
// - POST /chat/completions (stream: true) - отправка сообщения (streaming)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_chat_client.dart';

/// Реализация AiChatClient для OpenRouter.ai
class OpenRouterApiClient implements AiChatClient {
  final Uri baseUri; // https://openrouter.ai/api/v1
  final String apiKey;

  OpenRouterApiClient({
    required this.baseUri,
    required this.apiKey,
  });

  @override
  Future<List<AiModelInfo>> getModels() async {
    final headers = buildHeaders(apiKey);
    final uri = baseUri.replace(path: joinPath(baseUri.path, 'models/user'));
    final http.Response res = await safeGet(uri, headers);

    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((m) {
          final map = Map<String, dynamic>.from(m);

          final pricing = map['pricing'] is Map
              ? Map<String, dynamic>.from(map['pricing'])
              : const {};
          final prompt =
              double.tryParse(pricing['prompt']?.toString() ?? '') ?? 0.0;
          final completion =
              double.tryParse(pricing['completion']?.toString() ?? '') ?? 0.0;

          final ctx = (map['context_length'] ??
                  (map['top_provider'] is Map
                      ? (map['top_provider']['context_length'])
                      : null) ??
                  0)
              .toString();
          final contextLength = int.tryParse(ctx) ?? 0;

          return AiModelInfo(
            id: map['id']?.toString() ?? '',
            name: map['name']?.toString() ?? (map['id']?.toString() ?? ''),
            promptPrice: prompt,
            completionPrice: completion,
            contextLength: contextLength,
          );
        })
        .where((m) => m.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
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

    String extractError(dynamic decoded) {
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map) return err['message']?.toString() ?? 'Unknown error';
        if (err != null) return err.toString();
        if (decoded['message'] != null) return decoded['message'].toString();
      }
      return 'Unknown error';
    }

    Map<String, dynamic> decodeToMap(http.Response res) {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'error': 'Invalid JSON response'};
    }

    final chatUri =
        baseUri.replace(path: joinPath(baseUri.path, 'chat/completions'));

    final chatBody = {
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': message}
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': false,
    };

    try {
      final chatRes =
          await safePost(chatUri, headers, chatBody, cancelToken: cancelToken);
      final chatDecoded = decodeToMap(chatRes);

      if (chatRes.statusCode == 200) return chatDecoded;

      final chatErr = extractError(chatDecoded);

      if (!chatErr.contains("doesn't support endpoint") &&
          !chatErr.contains("does not support endpoint") &&
          !chatErr.contains("doesn't support")) {
        return {'error': chatErr};
      }

      // fallback -> /completions
      final compUri =
          baseUri.replace(path: joinPath(baseUri.path, 'completions'));
      final compBody = {
        'model': modelId,
        'prompt': message,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'stream': false,
      };

      final compRes =
          await safePost(compUri, headers, compBody, cancelToken: cancelToken);
      final compDecoded = decodeToMap(compRes);

      if (compRes.statusCode != 200) {
        final compErr = extractError(compDecoded);
        return {'error': compErr.isNotEmpty ? compErr : chatErr};
      }

      String text = '';
      final choices = compDecoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final c0 = choices.first;
        if (c0 is Map) {
          text = c0['text']?.toString() ??
              (c0['message'] is Map
                  ? (c0['message']['content']?.toString() ?? '')
                  : '');
        }
      }

      return {
        'choices': [
          {
            'message': {'content': text}
          }
        ],
        'usage': compDecoded['usage'],
      };
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

      // Пытаемся получить usage в конце стрима (OpenAI-like).
      // OpenRouter поддерживает “include usage” в стриме. :contentReference[oaicite:5]{index=5}
      'stream_options': {'include_usage': true},
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

      // Если сервер вернул НЕ SSE — fallback на обычный JSON body
      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('text/event-stream')) {
        final text = await res.stream.bytesToString();
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          yield decoded;
          return;
        }
        yield {'error': 'Invalid JSON response'};
        return;
      }

      // SSE parsing: data: {...}\n\n ... data: [DONE] :contentReference[oaicite:6]{index=6}
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
