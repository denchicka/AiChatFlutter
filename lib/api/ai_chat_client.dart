// Модуль для работы с API провайдеров ИИ (OpenRouter/VseGPT)
//
// Архитектура:
// - AiChatClient: абстрактный интерфейс для работы с API
// - OpenRouterApiClient: реализация для OpenRouter.ai
// - VseGptApiClient: реализация для VseGPT.ru
//
// Основные операции:
// - getModels(): получение списка доступных моделей
// - sendMessage(): отправка сообщения (non-streaming)
// - streamMessage(): отправка сообщения (streaming, SSE)
//
// Безопасность:
// - CancelToken: механизм отмены долгих запросов
// - safeGet/safePost: обёртки для HTTP с обработкой отмены
//
// Примечание:
// - Цены в promptPrice/completionPrice различаются по единицам:
//   * OpenRouter: цена за токен (обычно очень маленькие числа)
//   * VseGPT: цена за 1000 токенов (более крупные числа)

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Информация о модели ИИ
/// 
/// Содержит:
/// - id: уникальный идентификатор модели (например, "gpt-4", "claude-3-opus")
/// - name: человекочитаемое название
/// - promptPrice: цена за токен промпта (OpenRouter) или за 1K токенов (VseGPT)
/// - completionPrice: цена за токен ответа (OpenRouter) или за 1K токенов (VseGPT)
/// - contextLength: максимальная длина контекста в токенах
class AiModelInfo {
  final String id;
  final String name;
  /// Цена за токен промпта (OpenRouter) или за 1K токенов (VseGPT)
  final double promptPrice;
  /// Цена за токен ответа (OpenRouter) или за 1K токенов (VseGPT)
  final double completionPrice;
  /// Максимальная длина контекста в токенах
  final int contextLength;

  const AiModelInfo({
    required this.id,
    required this.name,
    required this.promptPrice,
    required this.completionPrice,
    required this.contextLength,
  });
}

/// Абстрактный интерфейс для работы с API провайдеров ИИ
/// 
/// Реализации:
/// - OpenRouterApiClient: для OpenRouter.ai
/// - VseGptApiClient: для VseGPT.ru
/// 
/// Все методы должны обрабатывать ошибки сети и возвращать понятные исключения
abstract class AiChatClient {
  /// Получить список доступных моделей
  /// 
  /// Возвращает список моделей с их характеристиками (цена, контекст и т.д.)
  /// Может выбросить исключение при проблемах с сетью или API
  Future<List<AiModelInfo>> getModels();

  /// Отправить сообщение и получить полный ответ (non-streaming)
  /// 
  /// Параметры:
  /// - message: текст сообщения пользователя
  /// - modelId: ID модели для использования
  /// - maxTokens: максимальное количество токенов в ответе
  /// - temperature: температура генерации (0.0-2.0)
  /// - cancelToken: токен для отмены запроса (опционально)
  /// 
  /// Возвращает Map с полями:
  /// - 'choices': список ответов модели
  /// - 'usage': статистика использования токенов
  /// - 'error': ошибка (если есть)
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String modelId,
    required int maxTokens,
    required double temperature,
    CancelToken? cancelToken,
  });

  /// Отправить сообщение и получить поток ответов (streaming, SSE)
  /// 
  /// Если провайдер не поддерживает streaming, можно использовать fallback на sendMessage()
  /// 
  /// Возвращает Stream с чанками ответа в реальном времени
  Stream<Map<String, dynamic>> streamMessage({
    required String message,
    required String modelId,
    required int maxTokens,
    required double temperature,
    CancelToken? cancelToken,
  });
}

/// Токен для отмены долгих HTTP запросов
/// 
/// Использование:
/// 1. Создать CancelToken перед запросом
/// 2. Передать в метод API (sendMessage/streamMessage)
/// 3. Вызвать cancel() для отмены запроса
/// 
/// После отмены HTTP клиент закрывается, запрос прерывается
class CancelToken {
  final Completer<String?> _c = Completer<String?>();
  bool get isCancelled => _c.isCompleted;
  Future<String?> get whenCancel => _c.future;

  void cancel([String? reason]) {
    if (!isCancelled) _c.complete(reason);
  }
}

String joinPath(String basePath, String suffix) {
  final a = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  final b = suffix.startsWith('/') ? suffix.substring(1) : suffix;
  return '$a/$b';
}

Map<String, String> buildHeaders(String apiKey) => <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'X-Title': 'AI Chat Flutter',
    };

Future<http.Response> safeGet(
  Uri uri,
  Map<String, String> headers, {
  CancelToken? cancelToken,
}) async {
  final client = http.Client();

  cancelToken?.whenCancel.then((_) {
    try {
      client.close();
    } catch (_) {}
  });

  try {
    return await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
  } finally {
    try {
      client.close();
    } catch (_) {}
  }
}

Future<http.Response> safePost(
  Uri uri,
  Map<String, String> headers,
  Object body, {
  CancelToken? cancelToken,
}) async {
  final client = http.Client();

  cancelToken?.whenCancel.then((_) {
    try {
      client.close();
    } catch (_) {}
  });

  try {
    return await client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
  } finally {
    try {
      client.close();
    } catch (_) {}
  }
}

/// Универсальный SSE -> JSON decoder.
/// Читает lines, собирает data: ..., событие заканчивается пустой строкой.
/// DONE завершает стрим.
Stream<Map<String, dynamic>> decodeSseToJson(
    Stream<List<int>> byteStream) async* {
  final lines =
      byteStream.transform(utf8.decoder).transform(const LineSplitter());

  final dataLines = <String>[];

  await for (final line in lines) {
    // keep-alive/comments
    if (line.startsWith(':')) continue;

    if (line.isEmpty) {
      if (dataLines.isEmpty) continue;

      final data = dataLines.join('\n').trim();
      dataLines.clear();

      if (data == '[DONE]') return;

      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        yield decoded;
      }
      continue;
    }

    if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trimLeft());
    }
  }
}
