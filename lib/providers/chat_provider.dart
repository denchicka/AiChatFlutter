// ChatProvider - основной провайдер состояния для чата
//
// Архитектура:
// - _ChatProviderBase: абстрактный базовый класс с общими полями и методами
// - Миксины (mixins) разделяют функциональность по областям:
//   * _ChatProviderSession: управление сессией (модели, баланс, конфигурация)
//   * _ChatProviderScrolling: управление прокруткой списка сообщений
//   * _ChatProviderData: работа с данными (история, статистика, агрегация)
//   * _ChatProviderRequests: отправка запросов к API (streaming, non-streaming)
//   * _ChatProviderActions: действия пользователя (отправка, регенерация, экспорт)
//
// Зависимости:
// - DatabaseService: сохранение/загрузка сообщений
// - AnalyticsService: сбор статистики использования
// - AiChatClient: клиент для работы с API (OpenRouter/VseGPT)
// - SettingsProvider: настройки приложения (уведомления и т.д.)
//
// Жизненный цикл:
// 1. Создание ChatProvider()
// 2. configureSession() - настройка провайдера и API ключа
// 3. _loadModels() - загрузка доступных моделей
// 4. _loadBalance() - загрузка баланса
// 5. _loadHistory() - загрузка истории сообщений из БД

// Импорт библиотеки для работы с JSON
import 'dart:convert';
// Импорт библиотеки для работы с файловой системой
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';
// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';
// Импорт пакета для получения путей к директориям
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Импорт модели сообщения
import '../models/message.dart';
// Импорт сервиса для работы с базой данных
import '../services/database_service.dart';
// Импорт сервиса для аналитики
import '../services/analytics_service.dart';
import '../settings/settings_provider.dart';
import '../settings/notify_service.dart';

import '../features/auth/domain/ai_provider_detector.dart';

import '../analytics/provider_ids.dart';

import '../api/ai_chat_client.dart';
import '../api/openrouter_api_client.dart';
import '../api/vsegpt_api_client.dart';
import '../api/auth_balance_client.dart';
import '../chat/domain/services/cost_calculator.dart';
import '../chat/domain/utils/provider_utils.dart';


part 'chat_provider_models.dart';
part 'chat_provider_scrolling.dart';
part 'chat_provider_session.dart';
part 'chat_provider_data.dart';
part 'chat_provider_requests.dart';
part 'chat_provider_actions.dart';

/// Базовый класс для ChatProvider
/// 
/// Содержит:
/// - Состояние сессии (клиент, провайдер, API ключ)
/// - Состояние запросов (токен отмены, ID активного запроса)
/// - Состояние UI (индекс печатающего сообщения, toast сообщения)
/// - Списки данных (сообщения, модели, логи)
/// 
/// Используется через миксины для разделения ответственности
abstract class _ChatProviderBase extends ChangeNotifier {
  // === Состояние сессии ===
  /// Клиент для работы с API (OpenRouter или VseGPT)
  AiChatClient? _client;
  
  /// Тип провайдера (openRouter или vseGpt)
  AiProviderType? _providerType;
  
  /// Базовый URI API провайдера
  Uri? _baseUri;
  
  /// API ключ для аутентификации
  String? _apiKey;

  // === Состояние запросов ===
  /// Токен для отмены текущего запроса
  CancelToken? _cancelToken;
  
  /// Уникальный ID текущего активного запроса (инкрементируется при каждом новом запросе)
  int _activeRequestId = 0;
  
  /// Индекс сообщения, которое сейчас "печатается" (показывается индикатор загрузки)
  int? _typingIndex;
  
  /// Флаг отмены запроса пользователем
  bool _cancelledByUser = false;

  // === Состояние UI ===
  /// Сообщение для показа в toast (уведомление пользователю)
  String? _toastMessage;
  String? get toastMessage => _toastMessage;
  
  /// Провайдер настроек (для доступа к настройкам уведомлений и т.д.)
  SettingsProvider? _settings;
  
  /// Флаг генерации ответа (используется для блокировки UI)
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;
  
  /// Индекс сообщения, к которому нужно прокрутить список (используется ChatScreen)
  int? _pendingScrollIndex;

  // === Константы для хранения выбранной модели ===
  static const _kLastModelOpenRouter = 'last_model_openrouter';
  static const _kLastModelVseGpt = 'last_model_vsegpt';
  
  /// Генератор случайных чисел для создания уникальных ID
  final _rnd = math.Random();

  int? _contextLenForModel(String modelId) {
    final m = _availableModels.firstWhere(
      (x) => (x['id']?.toString() ?? '') == modelId,
      orElse: () => <String, dynamic>{},
    );

    final raw = m['context_length']?.toString();
    return int.tryParse(raw ?? '');
  }

  int _estimateTokensRough(String text) {
    // усреднённо 1 токен ≈ 3–4 символа; берём консервативно 3
    final chars = text.runes.length;
    return (chars / 3).ceil();
  }

  int _maxTokensForRequest(String modelId, {required String promptText}) {
    final paidDefault = int.tryParse(dotenv.env['MAX_TOKENS'] ?? '') ?? 1000;

    // платные — как раньше
    if (!isModelFree(modelId)) return paidDefault;

    // потолок для free (лучше держать разумным)
    final envFree = int.tryParse(dotenv.env['MAX_TOKENS_FREE'] ?? '');
    final hardCap = (envFree != null && envFree > 0) ? envFree : 8192;

    final ctx = _contextLenForModel(modelId);
    if (ctx == null) {
      // если контекст неизвестен — не разгоняемся
      return (paidDefault * 2).clamp(paidDefault, hardCap).toInt();
    }

    const reserve = 1024; // увеличил, 512 слишком оптимистично
    final promptTok = _estimateTokensRough(promptText);

    final allowed =
        ctx - reserve - promptTok; // сколько реально можно отдать в output
    if (allowed <= 0) return 64; // совсем мало места — просим минимально

    // берём минимум из hardCap и allowed
    final out = math.min(hardCap, allowed);

    // можно ещё гарантировать не меньше paidDefault, но ТОЛЬКО если это не превышает allowed
    return math.max(64, math.min(out, math.max(paidDefault, 64)));
  }

  String _prefsKeyForProvider(AiProviderType t) {
    return switch (t) {
      AiProviderType.openRouter => _kLastModelOpenRouter,
      AiProviderType.vseGpt => _kLastModelVseGpt,
    };
  }

  Future<void> _persistLastModelSelectionFor(
    AiProviderType providerType,
    String modelId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyForProvider(providerType), modelId);
  }

  void setSettings(SettingsProvider sp) => _settings = sp;

  void _setGenerating(bool v) {
    if (_isGenerating == v) return;
    _isGenerating = v;
    notifyListeners();
  }

  void _emitToast(String msg) {
    _toastMessage = msg;
    notifyListeners();
  }

  void clearToast() {
    if (_toastMessage == null) return;
    _toastMessage = null;
    notifyListeners();
  }

  bool get isVseGpt => _providerType == AiProviderType.vseGpt;
  AiProviderType? get providerType => _providerType;

  final AuthBalanceClient _balanceClient = AuthBalanceClient();
  // Сервис для работы с базой данных
  final DatabaseService _db = DatabaseService();
  // Сервис для сбора аналитики
  final AnalyticsService _analytics = AnalyticsService();

  DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);


  // === Данные чата ===
  /// Список всех сообщений в чате (в хронологическом порядке)
  final List<ChatMessage> _messages = [];
  
  /// Логи для отладки (сохраняются в памяти, можно экспортировать)
  final List<String> _debugLogs = [];
  
  /// Список доступных моделей AI (загружается с API провайдера)
  /// Формат: [{'id': 'model-id', 'name': 'Model Name', 'pricing': {...}, ...}]
  List<Map<String, dynamic>> _availableModels = [];
  
  /// ID текущей выбранной модели (null если не выбрана)
  String? _currentModel;
  
  /// Баланс пользователя в формате строки (например, "$0.00" или "0.00 кр.")
  String _balance = '\$0.00';
  
  /// Флаг загрузки (true = идет запрос к API, блокирует UI)
  bool _isLoading = false;

  String _newUid() =>
      'm_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1 << 32)}';
  String _newTurnId() =>
      't_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1 << 32)}';

  // Метод для логирования сообщений
  void _log(String message) {
    // Добавление сообщения в логи с временной меткой
    _debugLogs.add('${DateTime.now()}: $message');
    // Вывод сообщения в консоль
    debugPrint(message);
  }

  // Геттер для получения неизменяемого списка сообщений
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  // Геттер для получения списка доступных моделей
  List<Map<String, dynamic>> get availableModels => _availableModels;
  // Геттер для получения текущей модели
  String? get currentModel => _currentModel;
  // Геттер для получения баланса
  String get balance => _balance;
  // Геттер для получения состояния загрузки
  bool get isLoading => _isLoading;

  String? get topUpUrl {
    return switch (_providerType) {
      AiProviderType.openRouter => 'https://openrouter.ai/settings/credits',
      AiProviderType.vseGpt => 'https://vsegpt.ru/User/Money',
      _ => null,
    };
  }

  String _formatBalance(double value) {
    if (!value.isFinite) {
      return isVseGpt ? '0.00 кр.' : '\$0.00';
    }

    if (isVseGpt) {
      // VseGPT: как было (можно оставить ₽ или "кр.", у тебя в коде оба варианта встречаются)
      return '${value.toStringAsFixed(2)} кр.';
    }

    // OpenRouter: показываем знак нормально: -$0.02, а не $-0.02
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();

    // чтобы не было "-$0.00" при микроминусе
    if (abs < 0.005) return '\$0.00';

    // если очень маленькая величина, но важен знак
    if (abs < 0.01) return '$sign<\$0.01';

    return '$sign\$${abs.toStringAsFixed(2)}';
  }

  /// Статистика использования по моделям (для /stats)
  // Сохраняем старый контракт для текущего UI:
  Map<String, ModelUsage> get usageByModel => usageByModelForRange();

  /// Расходы по дням (для /chart)
  List<DailySpend> get dailySpend {
    final agg = dailyAggregatesForRange();
    return agg.map((e) => DailySpend(day: e.day, cost: e.cost)).toList();
  }

  List<DailyAggregate> get dailyAggregates => dailyAggregatesForRange();

  double _balanceValue = 0.0; // числовой баланс для расчёта стоимости

  double get balanceValue => _balanceValue;

  double _normalizeMoney2(double v) {
    const eps = 0.005; // половина шага при округлении до 2 знаков
    return (v.abs() < eps) ? 0.0 : v;
  }

  // Геттер для получения базового URL
  String? get baseUrl => _baseUri?.toString();

  _ChatProviderBase();

  // Метод инициализации провайдера
  // Future<void> _initializeProvider() async {
  //   try {
  //     // Логирование начала инициализации
  //     _log('Initializing provider...');
  //     // Загрузка доступных моделей
  //     await _loadModels();
  //     _log('Models loaded: $_availableModels');
  //     // Загрузка баланса
  //     await _loadBalance();
  //     _log('Balance loaded: $_balance');
  //     // Загрузка истории сообщений
  //     await _loadHistory();
  //     _log('History loaded: ${_messages.length} messages');
  //   } catch (e, stackTrace) {
  //     // Логирование ошибок инициализации
  //     _log('Error initializing provider: $e');
  //     _log('Stack trace: $stackTrace');
  //   }
  // }

  String? _prefsKeyForCurrentProvider() {
    final pt = _providerType;
    if (pt == null) return null;
    return _prefsKeyForProvider(pt);
  }

  Future<void> _persistLastModelSelection(String modelId) async {
    final pt = _providerType;
    if (pt == null) return;
    await _persistLastModelSelectionFor(pt, modelId);
  }

  Future<void> _restoreLastModelSelectionIfPossible() async {
    final key = _prefsKeyForCurrentProvider();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(key);
    if (saved == null) return;

    final exists =
        _availableModels.any((m) => (m['id']?.toString() ?? '') == saved);
    if (!exists) return;

    if (_currentModel != saved) {
      _currentModel = saved;
      notifyListeners();
    }
  }

  bool _modelsFreeOnly = false;
  bool get modelsFreeOnly => _modelsFreeOnly;

  bool isModelFree(String? modelId);

  Map<String, ModelUsage> usageByModelForRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter,
  });

  List<DailyAggregate> dailyAggregatesForRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter,
  });

  Future<void> _loadHistory();
  Future<void> _repairMissingProviderIds();
  Future<void> _loadModels();
  Future<double?> _loadBalance();
  Future<void> _saveMessage(ChatMessage message);
  Future<void> _activateVariant({
    required String turnId,
    required String activeUid,
  });
  ChatMessage? _userMessageForTurn(String turnId);
  List<ChatMessage> _buildContextUpToTurn(String targetTurnId);
  String _buildPseudoChatPrompt(List<ChatMessage> ctx);
  double? _calcCostForModel({
    required String modelId,
    required bool pricedAsVseGpt,
    required int promptTokens,
    required int completionTokens,
    double? totalCostFromApi,
  });
  double? _tryParseDouble(dynamic v);
  int? _normTokens(dynamic v);
  String _providerKey();
  Future<void> _notifyAnswerIfNeeded({
    required String userText,
    required String assistantText,
  });
}

class ChatProvider extends _ChatProviderBase
    with
        _ChatProviderSession,
        _ChatProviderScrolling,
        _ChatProviderData,
        _ChatProviderRequests,
        _ChatProviderActions {
  ChatProvider() {
    _initializeProvider();
  }
}
