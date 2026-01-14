import 'dart:async'; // <-- обязательно для TimeoutException
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../features/auth/domain/ai_provider_detector.dart';
import '../features/auth/domain/auth_exceptions.dart';

/// Клиент для получения баланса от провайдеров AI
///
/// Поддерживает два типа провайдеров:
/// - VseGPT: использует endpoint /balance, возвращает credits
/// - OpenRouter: использует endpoint /credits, возвращает total_credits - total_usage
///
/// Обрабатывает различные типы ошибок (сеть, авторизация, формат данных)
/// и преобразует их в AuthException с понятными сообщениями.
class AuthBalanceClient {
  /// Получает баланс от указанного провайдера
  ///
  /// [providerType] - тип провайдера (VseGPT или OpenRouter)
  /// [baseUri] - базовый URI API провайдера (например, https://api.vsegpt.ru:6070/v1)
  /// [apiKey] - API ключ для аутентификации
  ///
  /// Возвращает баланс в виде числа (рубли для VseGPT, доллары для OpenRouter).
  /// Для OpenRouter может быть отрицательным (usage allowance).
  ///
  /// Выбрасывает AuthException в случае ошибок:
  /// - AuthErrorCode.unauthorized - неверный API ключ
  /// - AuthErrorCode.network - проблемы с сетью или таймаут
  /// - AuthErrorCode.badResponse - некорректный ответ сервера
  Future<double> getBalanceOrThrow({
    required AiProviderType providerType,
    required Uri baseUri,
    required String apiKey,
  }) async {
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'X-Title': 'AI Chat Flutter',
    };

    // ВАЖНО: baseUri = .../v1  => итог должен стать .../v1/balance
    final endpointUri = switch (providerType) {
      AiProviderType.vseGpt => baseUri.replace(path: '${baseUri.path}/balance'),
      AiProviderType.openRouter =>
        baseUri.replace(path: '${baseUri.path}/credits'),
    };

    try {
      final response = await http
          .get(endpointUri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthException(
          AuthErrorCode.unauthorized,
          'Ключ недействителен или доступ запрещён.',
        );
      }

      if (response.statusCode != 200) {
        throw AuthException(
          AuthErrorCode.badResponse,
          'Сервис вернул ошибку (HTTP ${response.statusCode}).',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw AuthException(
          AuthErrorCode.badResponse,
          'Некорректный ответ сервиса: отсутствует поле data.',
        );
      }

      switch (providerType) {
        case AiProviderType.vseGpt:
          final credits = double.tryParse(data['credits'].toString()) ?? 0.0;
          return max(0.0, _normalizeNegativeZero(credits));

        case AiProviderType.openRouter:
          final totalCredits =
              double.tryParse(data['total_credits'].toString()) ?? 0.0;
          final totalUsage =
              double.tryParse(data['total_usage'].toString()) ?? 0.0;

          final remainingRaw = totalCredits - totalUsage;

          // ВАЖНО: у OpenRouter допустим небольшой минус (usage allowance),
          // поэтому НЕЛЬЗЯ max(0.0, ...)
          return _normalizeNegativeZero(remainingRaw);
      }
    } on TimeoutException {
      // TimeoutException находится в dart:async :contentReference[oaicite:2]{index=2}
      throw AuthException(
        AuthErrorCode.network,
        'Сервис не отвечает (таймаут).',
      );
    } on SocketException catch (e) {
      final details = e.osError?.message ?? e.message;
      throw AuthException(
        AuthErrorCode.network,
        'Не удалось подключиться к ${endpointUri.host}. Детали: $details',
      );
    } on FormatException {
      throw AuthException(
        AuthErrorCode.badResponse,
        'Сервис вернул некорректные данные.',
      );
    }
  }

  /// Нормализует очень маленькие значения к нулю
  ///
  /// Для отображения с 2 знаками после запятой:
  /// всё, что меньше половины "копейки" (0.005) -> 0.00
  ///
  /// Это предотвращает отображение значений типа -0.001 как отрицательных,
  /// что может быть допустимо для OpenRouter (usage allowance).
  ///
  /// [value] - значение для нормализации
  /// Возвращает нормализованное значение (0.0 для очень маленьких чисел)
  double _normalizeNegativeZero(double value) {
    // для отображения с 2 знаками:
    // всё, что меньше половины "копейки" -> 0.00
    const eps = 0.005;
    if (value.abs() < eps) return 0.0;
    return value;
  }
}
