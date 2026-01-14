part of 'chat_provider.dart';

mixin _ChatProviderActions on _ChatProviderBase {
  // Метод установки текущей модели
  void setCurrentModel(String modelId) {
    if (_currentModel == modelId) return;
    _currentModel = modelId;
    notifyListeners();
    unawaited(_persistLastModelSelection(modelId));
  }

  // Метод очистки истории
  Future<void> clearHistory() async {
    // Очистка списка сообщений
    _messages.clear();
    // Очистка истории в базе данных
    await _db.clearHistory();
    // Очистка данных аналитики
    _analytics.clearData();
    // Уведомление слушателей об изменениях
    notifyListeners();
  }

  // Метод экспорта логов
  Future<String> exportLogs() async {
    // Получение директории для сохранения файла
    final directory = await getApplicationDocumentsDirectory();
    // Генерация имени файла с текущей датой и временем
    final now = DateTime.now();
    final fileName =
        'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';
    // Создание файла
    final file = File('${directory.path}/$fileName');

    // Создание буфера для записи логов
    final buffer = StringBuffer();
    buffer.writeln('=== Debug Logs ===\n');
    // Запись всех логов
    for (final log in _debugLogs) {
      buffer.writeln(log);
    }

    buffer.writeln('\n=== Chat Logs ===\n');
    // Запись времени генерации
    buffer.writeln('Generated: ${now.toString()}\n');

    // Запись всех сообщений
    for (final message in _messages) {
      buffer.writeln('${message.isUser ? "User" : "AI"} (${message.modelId}):');
      buffer.writeln(message.content);
      // Запись количества токенов, если есть
      if (message.tokens != null) {
        buffer.writeln('Tokens: ${message.tokens}');
      }
      // Запись времени сообщения
      buffer.writeln('Time: ${message.timestamp}');
      buffer.writeln('---\n');
    }

    // Запись содержимого в файл
    await file.writeAsString(buffer.toString());
    // Возвращение пути к файлу
    return file.path;
  }

  // Метод экспорта сообщений в формате JSON
  Future<String> exportMessagesAsJson() async {
    // Получение директории для сохранения файла
    final directory = await getApplicationDocumentsDirectory();
    // Генерация имени файла с текущей датой и временем
    final now = DateTime.now();
    final fileName =
        'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';
    // Создание файла
    final file = File('${directory.path}/$fileName');

    // Преобразование сообщений в JSON
    final List<Map<String, dynamic>> messagesJson =
        _messages.map((message) => message.toJson()).toList();

    // Запись JSON в файл
    await file.writeAsString(jsonEncode(messagesJson));
    // Возвращение пути к файлу
    return file.path;
  }

  String formatPricing(double pricing) {
    if (isVseGpt) {
      return '${pricing.toStringAsFixed(3)}₽/K';
    } else {
      return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
    }
  }

  @override
  String _providerKey() {
    if (_providerType == null) return ProviderIds.unknown;
    return ProviderUtils.providerIdFromType(_providerType!);
  }

  // Метод экспорта истории
  Future<Map<String, dynamic>> exportHistory() async {
    // Получение статистики из базы данных
    final dbStats = await _db.getStatistics();
    // Получение статистики аналитики
    final analyticsStats = _analytics.getStatistics();
    // Получение данных сессий
    final sessionData = _analytics.exportSessionData();
    // Получение эффективности моделей
    final modelEfficiency = _analytics.getModelEfficiency();
    // Получение статистики времени ответа
    final responseTimeStats = _analytics.getResponseTimeStats();
    // Получение статистики длины сообщений
    final messageLengthStats = _analytics.getMessageLengthStats();

    // Возвращение всех данных в виде Map
    return {
      'database_stats': dbStats,
      'analytics_stats': analyticsStats,
      'session_data': sessionData,
      'model_efficiency': modelEfficiency,
      'response_time_stats': responseTimeStats,
      'message_length_stats': messageLengthStats,
    };
  }

  @override
  bool isModelFree(String? modelId) {
    if (modelId == null || modelId.isEmpty) return false;

    Map<String, dynamic>? m;
    for (final x in _availableModels) {
      if ((x['id']?.toString() ?? '') == modelId) {
        m = x;
        break;
      }
    }
    if (m == null) return false;

    double parse(dynamic v) =>
        double.tryParse(v?.toString() ?? '') ?? double.nan;

    final p = parse(m['pricing']?['prompt']);
    final c = parse(m['pricing']?['completion']);

    if (!p.isFinite || !c.isFinite) return false;
    return p == 0.0 && c == 0.0;
  }

  Future<void> refreshAll() async {
    // если клиент/провайдер не настроены — просто выходим
    if (_client == null ||
        _providerType == null ||
        _baseUri == null ||
        _apiKey == null) {
      return;
    }

    // независимо, чтобы одно не ломало другое
    await Future.wait([
      _loadModels(),
      _loadBalance(),
    ]);
  }

  @override
  Future<void> _notifyAnswerIfNeeded({
    required String userText,
    required String assistantText,
  }) async {
    final sp = _settings;
    if (sp == null) return;

    final s = sp.s;

    // главный флаг "уведомлять об ответе"
    if (!s.notifyOnAnswer) return;

    // если ни один канал не включен — выходим
    if (!s.notifyTelegramEnabled && !s.notifyEmailEnabled) return;

    // не уведомляем о пустом/служебном
    final a = assistantText.trim();
    if (a.isEmpty || a == '…') return;
    if (a.startsWith('Ошибка:') || a.startsWith('Error:')) return;

    try {
      await NotifyService.instance.notifyOnAnswer(
        s: s, // ваши AppSettings
        userText: userText, // исходный вопрос
        assistantText: assistantText, // финальный ответ (НЕ chunk)
      );
      _log('Notify on answer: успешно отправлено');
    } catch (e) {
      _log('Notify on answer failed: $e');
      // Показываем toast только если включен email или telegram, чтобы пользователь знал о проблеме
      if (s.notifyEmailEnabled || s.notifyTelegramEnabled) {
        _emitToast('Уведомление не отправлено: $e');
      }
    }
  }
}
