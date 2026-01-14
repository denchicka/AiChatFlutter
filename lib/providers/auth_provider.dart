// AuthProvider - провайдер состояния для управления авторизацией
//
// Ответственность:
// - Хранение и проверка API ключей (OpenRouter/VseGPT)
// - Генерация и проверка PIN кода для защиты ключа
// - Управление жизненным циклом авторизации (stages)
// - Шифрование/дешифрование API ключей для безопасного хранения
//
// Жизненный цикл авторизации:
// 1. unknown - начальное состояние (проверка сохранённых данных)
// 2. needsApiKey - требуется ввод API ключа (первый запуск или сброс)
// 3. needsPin - ключ сохранён, требуется PIN для разблокировки
// 4. authenticated - пользователь авторизован, доступ к чату открыт
//
// Безопасность:
// - API ключи шифруются перед сохранением в БД (AuthCryptoService)
// - PIN хешируется (SHA-256) перед сохранением
// - Расшифрованный ключ хранится только в памяти (decryptedApiKeyForSession)
//
// Зависимости:
// - DatabaseService: сохранение/загрузка зашифрованных данных
// - AuthCryptoService: шифрование/хеширование
// - AuthBalanceClient: проверка валидности ключа через API

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../features/auth/domain/ai_provider_detector.dart';
import '../features/auth/domain/auth_exceptions.dart';
import '../api/auth_balance_client.dart';
import '../services/auth_crypto_service.dart';
import '../services/database_service.dart';

/// Стадии процесса авторизации пользователя
enum AuthenticationStage {
  /// Начальное состояние - проверка сохранённых данных
  unknown,
  /// Требуется ввод API ключа (первый запуск или после сброса)
  needsApiKey,
  /// Ключ сохранён, требуется PIN для разблокировки
  needsPin,
  /// Пользователь авторизован, доступ к приложению открыт
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  final DatabaseService databaseService;
  final AuthCryptoService authCryptoService;
  final AuthBalanceClient authBalanceClient;

  AuthenticationStage authenticationStage = AuthenticationStage.unknown;

  String? lastErrorMessage;
  bool isProcessing = false;

  AiProviderType? storedProviderType;
  String? decryptedApiKeyForSession;

  /// PIN, который надо показать сразу после регистрации
  String? pendingGeneratedPin;

  AuthProvider({
    required this.databaseService,
    required this.authCryptoService,
    required this.authBalanceClient,
  });

  Future<void> initializeAuthenticationState() async {
    final authRecord = await databaseService.getAuth();

    if (authRecord == null) {
      storedProviderType = null;
      decryptedApiKeyForSession = null;
      authenticationStage = AuthenticationStage.needsApiKey;
      notifyListeners();
      return;
    }

    final providerString = authRecord['provider'] as String?;
    if (providerString == 'openrouter') {
      storedProviderType = AiProviderType.openRouter;
    } else if (providerString == 'vsegpt') {
      storedProviderType = AiProviderType.vseGpt;
    }

    decryptedApiKeyForSession = null;
    authenticationStage = AuthenticationStage.needsPin;
    notifyListeners();
  }

  Future<String> registerApiKeyAndGeneratePin({
    required String apiKeyEnteredByUser,
    AiProviderType? providerOverride,
  }) async {
    _setProcessing(true);
    lastErrorMessage = null;

    try {
      final trimmedApiKey = apiKeyEnteredByUser.trim();

      final detectedProviderType = providerOverride ??
          AiProviderDetector.detectProviderTypeFromApiKey(trimmedApiKey);

      if (detectedProviderType == null) {
        throw AuthException(
          AuthErrorCode.invalidKeyFormat,
          'Не удалось определить провайдера. Выберите провайдера вручную.',
        );
      }

      final baseUri = AiProviderDetector.defaultBaseUri(detectedProviderType);

      final balance = await authBalanceClient.getBalanceOrThrow(
        providerType: detectedProviderType,
        baseUri: baseUri,
        apiKey: trimmedApiKey,
      );

      final pinNumber = Random.secure().nextInt(10000);
      final pinCode = pinNumber.toString().padLeft(4, '0');

      final pinHash = authCryptoService.hashPinCodeForStorage(pinCode: pinCode);
      final encryptedApiKey = await authCryptoService.encryptApiKeyForDatabase(
        plainApiKey: trimmedApiKey,
      );

      await databaseService.saveAuth(
        provider: detectedProviderType == AiProviderType.openRouter
            ? 'openrouter'
            : 'vsegpt',
        apiKey: encryptedApiKey,
        pinHash: pinHash,
        lastBalance: balance,
        lastCheckedAt: DateTime.now(),
      );

      storedProviderType = detectedProviderType;
      decryptedApiKeyForSession = trimmedApiKey;

      // КРИТИЧНО: НЕ ставим authenticated здесь — иначе go_router утащит на /chat
      pendingGeneratedPin = pinCode;

      // Остаёмся на needsApiKey (можно выделить отдельный stage, но не обязательно)
      authenticationStage = AuthenticationStage.needsApiKey;
      notifyListeners();

      return pinCode;
    } on AuthException catch (e) {
      lastErrorMessage = e.message;
      rethrow;
    } catch (e) {
      lastErrorMessage = 'Не удалось обработать ключ. Попробуйте ещё раз.';
      throw AuthException(AuthErrorCode.unknown, lastErrorMessage!);
    } finally {
      _setProcessing(false);
    }
  }

  /// Вызвать ПОСЛЕ того как PIN показан и пользователь нажал "Продолжить"
  void completeRegistrationAndEnter() {
    pendingGeneratedPin = null;
    authenticationStage = AuthenticationStage.authenticated;
    notifyListeners();
  }

  Future<void> unlockWithPin({required String pinCode}) async {
    _setProcessing(true);
    lastErrorMessage = null;

    try {
      final authRecord = await databaseService.getAuth();
      if (authRecord == null) {
        authenticationStage = AuthenticationStage.needsApiKey;
        notifyListeners();
        throw AuthException(AuthErrorCode.badResponse,
            'Сохранённые данные не найдены. Введите ключ заново.');
      }

      final storedPinHash = authRecord['pin_hash'] as String;
      final isPinValid = authCryptoService.verifyPinCode(
        pinCode: pinCode,
        storedPinHash: storedPinHash,
      );

      if (!isPinValid) {
        throw AuthException(AuthErrorCode.unauthorized, 'Неверный PIN');
      }

      final providerString = authRecord['provider'] as String;
      storedProviderType = providerString == 'openrouter'
          ? AiProviderType.openRouter
          : AiProviderType.vseGpt;

      final encryptedApiKey = authRecord['api_key'] as String;
      decryptedApiKeyForSession = await authCryptoService
          .decryptApiKeyFromDatabase(encryptedApiKey: encryptedApiKey);

      authenticationStage = AuthenticationStage.authenticated;
      notifyListeners();
    } on AuthException catch (e) {
      lastErrorMessage = e.message;
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> resetAuth() async {
    _setProcessing(true);
    try {
      await databaseService.clearAuth();
      storedProviderType = null;
      decryptedApiKeyForSession = null;
      pendingGeneratedPin = null;

      authenticationStage = AuthenticationStage.needsApiKey;
      notifyListeners();
    } finally {
      _setProcessing(false);
    }
  }

  void _setProcessing(bool value) {
    isProcessing = value;
    notifyListeners();
  }
}
