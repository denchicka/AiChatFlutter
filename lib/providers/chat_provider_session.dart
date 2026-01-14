part of 'chat_provider.dart';

mixin _ChatProviderSession on _ChatProviderBase {
  void cancelCurrentRequest() {
    if (!_isLoading) return;

    _cancelledByUser = true;
    _activeRequestId++;

    _cancelToken?.cancel('user_cancelled');
    final idx = _typingIndex;
    _cancelToken = null;

    if (idx != null && idx >= 0 && idx < _messages.length) {
      final prevMsg = _messages[idx];

      final prev = prevMsg.content;

      final newText = (prev.trim().isEmpty || prev == '…')
          ? 'Остановлено пользователем.'
          : '$prev\n\n_(Остановлено пользователем.)_';

      final msg = prevMsg.copyWith(
        content: newText,
        tokens: null,
        cost: null,
        isActiveVariant: true,
        // uid/turnId/createdAt/modelId/providerId уже в prevMsg — сохраняются
      );

      _messages[idx] = msg;
      unawaited(_saveMessage(msg));
      unawaited(_activateVariant(turnId: msg.turnId, activeUid: msg.uid));
    }

    unawaited(_loadBalance());
    _isLoading = false;
    notifyListeners();
  }

  void setModelsFreeOnly(bool v) {
    if (_modelsFreeOnly == v) return;
    _modelsFreeOnly = v;
    notifyListeners();
  }

  Future<void> _initializeProvider() async {
    try {
      _log('Initializing provider...');
      await _loadHistory();
      await _repairMissingProviderIds();
      _log('History loaded: ${_messages.length} messages');
    } catch (e, stackTrace) {
      // Логируем ошибку инициализации, но не прерываем работу приложения
      _log('Error initializing provider: $e');
      _log('Stack trace: $stackTrace');
      // Приложение продолжит работу, но история может быть не загружена
    }
  }

  Future<void> configureSession({
    required AiProviderType providerType,
    required Uri baseUri,
    required String apiKey,
  }) async {
    final changed = _providerType != providerType ||
        _baseUri != baseUri ||
        _apiKey != apiKey;

    final prevProviderType = _providerType;
    final prevModel = _currentModel;

    if (prevProviderType != null && prevModel != null) {
      await _persistLastModelSelectionFor(prevProviderType, prevModel);
    }

    _providerType = providerType;
    _baseUri = baseUri;
    _apiKey = apiKey;

    if (!changed) return;

    _client = switch (providerType) {
      AiProviderType.openRouter =>
        OpenRouterApiClient(baseUri: baseUri, apiKey: apiKey),
      AiProviderType.vseGpt =>
        VseGptApiClient(baseUri: baseUri, apiKey: apiKey),
    };

    // 1) показать кэшированный баланс сразу (чтобы при старте не было "$0.00")
    final auth = await _db.getAuth();
    final cached = auth?['last_balance'];
    if (cached is num) {
      final v = _normalizeMoney2(cached.toDouble());
      _balanceValue = v;
      _balance = _formatBalance(v);
      notifyListeners();
    } else {
      _balanceValue = 0.0;
      _balance = _formatBalance(0.0);
      notifyListeners();
    }

    // 2) models и balance грузим независимо (чтобы одно не убивало другое)
    try {
      await _loadModels();
    } catch (_) {}
    try {
      await _loadBalance();
    } catch (_) {}
  }

  // Метод загрузки доступных моделей
  @override
  Future<void> _loadModels() async {
    try {
      final client = _client;
      if (client == null) return;

      final models = await client.getModels();

      _availableModels = models
          .map<Map<String, dynamic>>((m) => <String, dynamic>{
                'id': m.id,
                'name': m.name,
                'pricing': <String, dynamic>{
                  'prompt': m.promptPrice.toString(),
                  'completion': m.completionPrice.toString(),
                },
                'context_length': m.contextLength.toString(),
              })
          .toList();

      // КРИТИЧНО: если моделей нет — сбрасываем текущую, чтобы Dropdown не падал
      if (_availableModels.isEmpty) {
        _currentModel = null;
      } else {
        final ids = _availableModels.map((e) => e['id'] as String).toSet();

        // если текущей модели нет в новом списке (сменили провайдера) — ставим первую
        if (_currentModel == null || !ids.contains(_currentModel)) {
          _currentModel = _availableModels.first['id'] as String;
        }
      }
      await _restoreLastModelSelectionIfPossible();

      // гарантируем запись итоговой модели (в т.ч. если выбралась первая автоматически)
      final cm = _currentModel;
      if (cm != null) {
        unawaited(_persistLastModelSelection(cm));
      }

      notifyListeners();
    } catch (e) {
      _log('Error loading models: $e');

      // чтобы UI не падал
      _availableModels = [];
      _currentModel = null;
      notifyListeners();
    }
  }

  // Метод загрузки баланса пользователя
  @override
  Future<double?> _loadBalance() async {
    try {
      if (_providerType == null || _baseUri == null || _apiKey == null) {
        return null;
      }

      final value = await _balanceClient.getBalanceOrThrow(
        providerType: _providerType!,
        baseUri: _baseUri!,
        apiKey: _apiKey!,
      );

      final v = _normalizeMoney2(value);
      _balanceValue = v;
      _balance = _formatBalance(v);

      await _db.updateAuthCheck(
          lastBalance: value, lastCheckedAt: DateTime.now());
      notifyListeners();
      return value;
    } catch (e) {
      _log('Error loading balance: $e');
      return null;
    }
  }

}
