part of 'chat_provider.dart';

mixin _ChatProviderRequests on _ChatProviderBase {
  /// Безопасный парсинг температуры из переменных окружения
  /// Если значение некорректное или отсутствует, возвращает значение по умолчанию 0.7
  double _safeParseTemperature(String tempStr) {
    // Убираем пробелы и проверяем на пустую строку
    final trimmed = tempStr.trim();
    if (trimmed.isEmpty) return 0.7;
    // Безопасный парсинг с обработкой ошибок
    return double.tryParse(trimmed) ?? 0.7;
  }

  // Метод отправки сообщения
  Future<void> sendMessage(String content, {bool trackAnalytics = true}) async {
    if (_isLoading) return;
    if (content.trim().isEmpty || _currentModel == null) return;
    final turnId = _newTurnId();
    final userUid = _newUid();
    final assistantUid = _newUid(); // uid будущего ответа (и плейсхолдера)

    // Фиксируем параметры запроса на момент отправки
    final usedModel = _currentModel!;
    final maxTokens = _maxTokensForRequest(usedModel, promptText: content);
    final usedProviderId = _providerKey();
    final usedPricedAsVseGpt = isVseGpt;
    final requestCreatedAt = DateTime.now();

    final int requestId = ++_activeRequestId;
    _cancelledByUser = false;

    _isLoading = true;
    notifyListeners();
    _setGenerating(true);

    final requestTimeoutSec =
        (int.tryParse(dotenv.env['REQUEST_TIMEOUT_SEC'] ?? '') ?? 120)
            .clamp(60, 600);
    final requestTimeout = Duration(seconds: requestTimeoutSec);

    int typingIndex = -1;

    try {
      content = utf8.decode(utf8.encode(content));

      // 1) user message
      final userMessage = ChatMessage(
        uid: userUid,
        turnId: turnId,
        isActiveVariant: true,
        content: content,
        isUser: true,
        createdAt: requestCreatedAt,
        modelId: usedModel,
        providerId: usedProviderId,
        pricedAsVseGpt: usedPricedAsVseGpt,
      );

      _messages.add(userMessage);
      // НЕ ждём запись в БД — иначе UI/скролл опаздывают
      unawaited(_saveMessage(userMessage));

      // 2) typing placeholder
      final typingMessage = ChatMessage(
        uid: assistantUid,
        turnId: turnId,
        isActiveVariant: false, // пока не финальный вариант
        content: '…',
        isUser: false,
        createdAt: DateTime.now(),
        modelId: usedModel,
        providerId: usedProviderId,
        pricedAsVseGpt: usedPricedAsVseGpt,
      );

      _messages.add(typingMessage);
      typingIndex = _messages.length - 1;
      _typingIndex = typingIndex;

      _pendingScrollIndex = typingIndex;
      notifyListeners();

      final startTime = DateTime.now();

      final client = _client;
      if (client == null) throw Exception('Client is not configured');

      // токен отмены НА ЭТОТ запрос
      _cancelToken = CancelToken();

      var streamEnabled =
          (dotenv.env['STREAM'] ?? 'false').toLowerCase() == 'true';

      // ---------------- STREAM ----------------
      if (streamEnabled) {
        Future<void> runStream() async {
          final buffer = StringBuffer();
          Map<String, dynamic>? lastUsage;
          var lastUiPush = DateTime.now();
          String? lastFinish;

          try {
            await for (final chunk in client
                .streamMessage(
                  message: content,
                  modelId: usedModel,
                  maxTokens: maxTokens,
                  temperature: _safeParseTemperature(dotenv.env['TEMPERATURE'] ?? '0.7'),
                  cancelToken: _cancelToken,
                )
                .timeout(requestTimeout)) {
              final fr = chunk['choices']?[0]?['finish_reason']?.toString();
              if (fr != null && fr.isNotEmpty) lastFinish = fr;

              if (requestId != _activeRequestId || _cancelledByUser) return;

              if (chunk['error']?.toString() == 'cancelled') return;

              if (chunk.containsKey('error')) {
                final err = chunk['error']?.toString() ?? 'Unknown error';

                final msg = _messages[typingIndex].copyWith(
                  content: 'Ошибка: $err',
                  tokens: null,
                  cost: null,
                  isActiveVariant: true,
                );

                _messages[typingIndex] = msg;
                notifyListeners();
                await _saveMessage(msg);
                await _activateVariant(turnId: msg.turnId, activeUid: msg.uid);
                return;
              }

              final usage = chunk['usage'];
              if (usage is Map) lastUsage = Map<String, dynamic>.from(usage);

              final delta = chunk['choices']?[0]?['delta']?['content'] ??
                  chunk['choices']?[0]?['message']?['content'] ??
                  chunk['choices']?[0]?['text'];

              final s = delta?.toString() ?? '';
              if (s.isNotEmpty) buffer.write(s);

              final now = DateTime.now();
              if (now.difference(lastUiPush).inMilliseconds >= 40) {
                lastUiPush = now;

                _messages[typingIndex] = _messages[typingIndex].copyWith(
                  content: buffer.isEmpty ? '…' : buffer.toString(),
                  // isActiveVariant остаётся false, пока не финализировали
                );

                notifyListeners();
              }
            }
          } catch (e) {
            // Если отмена — тихо выходим, UI обновится cancelCurrentRequest()
            if (_cancelledByUser || requestId != _activeRequestId) return;
            rethrow;
          }

          if (requestId != _activeRequestId || _cancelledByUser) return;

          // Полезно для диагностики, иначе переменная не используется.
          if (lastFinish != null) {
            _log('Stream finished: $lastFinish');
          }

          int? normTokens(num? v) {
            final t = v?.toInt();
            if (t == null || t <= 0) return null;
            return t;
          }

          final usage = lastUsage ?? <String, dynamic>{};
          final totalTokens = normTokens(usage['total_tokens'] as num?);
          final promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
          final completionTokens =
              (usage['completion_tokens'] as num?)?.toInt() ?? 0;

          final totalCostFromApi = _tryParseDouble(usage['total_cost']);

          // cost считаем только если есть хоть какая-то уверенность (tokens или total_cost)
          final cost = (totalTokens != null || totalCostFromApi != null)
              ? _calcCostForModel(
                  modelId: usedModel,
                  pricedAsVseGpt: usedPricedAsVseGpt,
                  promptTokens: promptTokens,
                  completionTokens: completionTokens,
                  totalCostFromApi: totalCostFromApi,
                )
              : null;

          final finalText = buffer.toString();

          final aiMessage = _messages[typingIndex].copyWith(
            content: finalText.isEmpty ? '…' : finalText,
            tokens: totalTokens,
            cost: cost,
            isActiveVariant: true,
          );

          _messages[typingIndex] = aiMessage;
          notifyListeners();
          await _saveMessage(aiMessage);
          await _activateVariant(turnId: turnId, activeUid: assistantUid);

          if (requestId == _activeRequestId && !_cancelledByUser) {
            unawaited(_notifyAnswerIfNeeded(
              userText: content,
              assistantText: aiMessage.content,
            ));
          }

          unawaited(_loadBalance());
        }

        try {
          await runStream().timeout(requestTimeout);
          return; // успех стрима
        } on TimeoutException catch (e) {
          _log('Stream timeout: $e. Fallback to non-stream.');
          _emitToast('Стрим не отвечает — переключаюсь на обычный режим.');

          _cancelToken?.cancel('stream_timeout');
          _cancelToken = CancelToken(); // новый токен под обычный запрос
          streamEnabled = false;
        } catch (e) {
          // если отмена пользователем — просто выходим
          if (_cancelledByUser || requestId != _activeRequestId) return;

          _log('Stream failed: $e. Fallback to non-stream.');
          _emitToast('Стрим недоступен — переключаюсь на обычный режим.');
          streamEnabled = false;
        }
      }

      // ---------------- NON-STREAM ----------------
      final response = await client
          .sendMessage(
            message: content,
            modelId: usedModel,
            maxTokens: maxTokens,
            temperature: _safeParseTemperature(dotenv.env['TEMPERATURE'] ?? '0.7'),
            cancelToken: _cancelToken,
          )
          .timeout(requestTimeout);

      if (requestId != _activeRequestId || _cancelledByUser) return;
      if (response['error']?.toString() == 'cancelled') return;

      final responseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      if (response.containsKey('error')) {
        final msg = _messages[typingIndex].copyWith(
          content: 'Ошибка API: ${response['error']}',
          tokens: null,
          cost: null,
          isActiveVariant: true,
        );

        _messages[typingIndex] = msg;
        notifyListeners();
        await _saveMessage(msg);
        await _activateVariant(turnId: turnId, activeUid: assistantUid);
        _emitToast('Ошибка API: ${response['error']}');
        return;
      }

      final aiContent =
          response['choices']?[0]?['message']?['content']?.toString();
      if (aiContent == null) throw Exception('Invalid API response format');

      final finish = response['choices']?[0]?['finish_reason']?.toString();
      if (finish == 'length') {
        _emitToast('Ответ обрезан по лимиту токенов (finish_reason=length)');
      }

      final usage = (response['usage'] is Map)
          ? Map<String, dynamic>.from(response['usage'])
          : <String, dynamic>{};

      final totalTokens = _normTokens(usage['total_tokens']);
      final promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
      final completionTokens =
          (usage['completion_tokens'] as num?)?.toInt() ?? 0;

      final totalCostFromApi = _tryParseDouble(usage['total_cost']);

      final cost = (totalTokens != null || totalCostFromApi != null)
          ? _calcCostForModel(
              modelId: usedModel,
              pricedAsVseGpt: usedPricedAsVseGpt,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              totalCostFromApi: totalCostFromApi,
            )
          : null;

      if (trackAnalytics) {
        _analytics.trackMessage(
          model: usedModel,
          messageLength: content.length,
          responseTime: responseTime,
          tokensUsed: totalTokens ?? 0,
        );
      }

      final aiMessage = _messages[typingIndex].copyWith(
        content: aiContent,
        tokens: totalTokens,
        cost: cost,
        isActiveVariant: true,
      );

      _messages[typingIndex] = aiMessage;
      notifyListeners();
      await _saveMessage(aiMessage);
      await _activateVariant(turnId: turnId, activeUid: assistantUid);

      if (requestId == _activeRequestId && !_cancelledByUser) {
        unawaited(_notifyAnswerIfNeeded(
          userText: content,
          assistantText: aiMessage.content,
        ));
      }

      await _loadBalance();
    } on TimeoutException catch (e) {
      _log('Timeout sending message: $e');
      _emitToast('Ошибка: превышено время ожидания ответа сервера.');

      if (_cancelledByUser || requestId != _activeRequestId) return;

      final msg = (typingIndex >= 0 && typingIndex < _messages.length)
          ? _messages[typingIndex].copyWith(
              content: 'Ошибка: превышено время ожидания ответа сервера.',
              tokens: null,
              cost: null,
              isActiveVariant: true,
            )
          : ChatMessage(
              uid: assistantUid,
              turnId: turnId,
              isActiveVariant: true,
              content: 'Ошибка: превышено время ожидания ответа сервера.',
              isUser: false,
              createdAt: DateTime.now(),
              modelId: usedModel,
              providerId: usedProviderId,
              pricedAsVseGpt: usedPricedAsVseGpt,
            );

      if (typingIndex >= 0 && typingIndex < _messages.length) {
        _messages[typingIndex] = msg;
      } else {
        _messages.add(msg);
      }
      notifyListeners();
      await _saveMessage(msg);
      await _activateVariant(turnId: msg.turnId, activeUid: msg.uid);
    } catch (e, st) {
      if (_cancelledByUser || requestId != _activeRequestId) return;

      // Логируем полную информацию об ошибке
      _log('Error sending message: $e');
      _log('Stack trace: $st');
      
      // Формируем понятное сообщение для пользователя
      final errorMessage = e is TimeoutException
          ? 'Превышено время ожидания ответа сервера'
          : e is SocketException
              ? 'Ошибка подключения к серверу'
              : e.toString().contains('cancelled')
                  ? 'Запрос отменён'
                  : 'Ошибка при отправке сообщения: ${e.toString().split('\n').first}';
      
      _emitToast(errorMessage);

      final ChatMessage msg;
      if (typingIndex >= 0 && typingIndex < _messages.length) {
        msg = _messages[typingIndex].copyWith(
          content: 'Ошибка: $e',
          tokens: null,
          cost: null,
          isActiveVariant: true,
        );
        _messages[typingIndex] = msg;
      } else {
        msg = ChatMessage(
          uid: assistantUid,
          turnId: turnId,
          isActiveVariant: true,
          content: 'Ошибка: $e',
          isUser: false,
          createdAt: DateTime.now(),
          modelId: usedModel,
          providerId: usedProviderId,
          pricedAsVseGpt: usedPricedAsVseGpt,
        );
        _messages.add(msg);
      }

      notifyListeners();
      await _saveMessage(msg);
      await _activateVariant(turnId: msg.turnId, activeUid: msg.uid);
    } finally {
      // очищаем cancelToken только если это всё ещё “текущий” запрос
      if (requestId == _activeRequestId) {
        _cancelToken = null;
        _isLoading = false;
        notifyListeners();
      }
      _setGenerating(false);
    }
  }

  Future<void> regenerateFromAiIndex(int aiIndex) async {
    if (aiIndex < 0 || aiIndex >= _messages.length) return;
    final m = _messages[aiIndex];
    if (m.isUser) return;
    return regenerateAnswerFor(m);
  }

  Future<void> regenerateAnswerFor(ChatMessage assistantMsg) async {
    if (_isLoading) return;
    if (assistantMsg.isUser) return;

    // Провайдер должен совпадать, иначе вы физически не отправите в другой backend
    final currentProviderId = _providerKey();
    if (assistantMsg.providerId != currentProviderId) {
      _emitToast(
          'Нельзя повторить: ответ был от другого провайдера. Переключитесь и попробуйте снова.');
      return;
    }

    final userMsg = _userMessageForTurn(assistantMsg.turnId) ??
        _fallbackUserBeforeAssistant(assistantMsg);

    if (userMsg == null) {
      _emitToast('Не найдено исходное сообщение для повтора.');
      return;
    }

    final usedModel = assistantMsg.modelId ?? _currentModel;

    if (usedModel == null) {
      _emitToast('Модель не выбрана.');
      return;
    }

    // 1) СНАЧАЛА собираем контекст и prompt (это реальный текст, который уйдёт в API)
    final ctx = _buildContextUpToTurn(userMsg.turnId);
    final prompt = _buildPseudoChatPrompt(ctx);

    // 2) ПОТОМ считаем maxTokens с учётом prompt
    final maxTokens = _maxTokensForRequest(usedModel, promptText: prompt);

    final assistantUid = _newUid();
    final typingMessage = ChatMessage(
      uid: assistantUid,
      turnId: assistantMsg.turnId,
      isActiveVariant: false,
      content: '…',
      isUser: false,
      createdAt: DateTime.now(),
      modelId: usedModel,
      providerId: assistantMsg.providerId,
      pricedAsVseGpt: assistantMsg.pricedAsVseGpt,
    );
    // добавляем в конец
    _messages.add(typingMessage);
    final typingIndex = _messages.length - 1;
    _typingIndex = typingIndex;

    _cancelledByUser = false;
    final int requestId = ++_activeRequestId;

    _isLoading = true;
    notifyListeners();
    _setGenerating(true);

    try {
      final client = _client;
      if (client == null) throw Exception('Client is not configured');

      final ctx = _buildContextUpToTurn(userMsg.turnId);
      final prompt = _buildPseudoChatPrompt(ctx);

      _cancelToken = CancelToken();

      final requestTimeoutSec =
          (int.tryParse(dotenv.env['REQUEST_TIMEOUT_SEC'] ?? '') ?? 120)
              .clamp(60, 600);
      final requestTimeout = Duration(seconds: requestTimeoutSec);

      // ВАЖНО: тут используем ваш текущий клиент (single message).
      // Если позже переведёте API на messages[] — замените prompt на нормальный chat payload.
      final response = await client
          .sendMessage(
            message: prompt,
            modelId: usedModel,
            maxTokens: maxTokens,
            temperature: _safeParseTemperature(dotenv.env['TEMPERATURE'] ?? '0.7'),
            cancelToken: _cancelToken,
          )
          .timeout(requestTimeout);

      if (requestId != _activeRequestId || _cancelledByUser) return;
      if (response['error']?.toString() == 'cancelled') return;

      if (response.containsKey('error')) {
        final err = response['error']?.toString() ?? 'Unknown error';

        final msg = _messages[typingIndex].copyWith(
          content: 'Ошибка: $err',
          tokens: null,
          cost: null,
          isActiveVariant: true,
        );

        _messages[typingIndex] = msg;
        notifyListeners();
        await _saveMessage(msg);
        await _activateVariant(
            turnId: assistantMsg.turnId, activeUid: assistantUid);

        _emitToast('Ошибка API: $err');
        return;
      }

      final aiContent =
          response['choices']?[0]?['message']?['content']?.toString();
      if (aiContent == null) throw Exception('Invalid API response format');

      final usage = (response['usage'] is Map)
          ? Map<String, dynamic>.from(response['usage'])
          : <String, dynamic>{};

      final totalTokens = _normTokens(usage['total_tokens']);
      final promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
      final completionTokens =
          (usage['completion_tokens'] as num?)?.toInt() ?? 0;

      final totalCostFromApi = _tryParseDouble(usage['total_cost']);

      final cost = (totalTokens != null || totalCostFromApi != null)
          ? _calcCostForModel(
              modelId: usedModel,
              pricedAsVseGpt: assistantMsg.pricedAsVseGpt,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              totalCostFromApi: totalCostFromApi,
            )
          : null;

      final finalMsg = _messages[typingIndex].copyWith(
        content: aiContent,
        tokens: totalTokens,
        cost: cost,
        isActiveVariant: true,
      );

      _messages[typingIndex] = finalMsg;
      notifyListeners();
      await _saveMessage(finalMsg);

      // Делает новый вариант активным и выключает старые
      await _activateVariant(
          turnId: assistantMsg.turnId, activeUid: assistantUid);

      unawaited(_loadBalance());

      unawaited(_notifyAnswerIfNeeded(
        userText: userMsg.content,
        assistantText: aiContent,
      ));
    } on TimeoutException {
      if (_cancelledByUser || requestId != _activeRequestId) return;

      final msg = _messages[typingIndex].copyWith(
        content: 'Ошибка: превышено время ожидания ответа сервера.',
        tokens: null,
        cost: null,
        isActiveVariant: true,
      );

      _messages[typingIndex] = msg;
      notifyListeners();
      await _saveMessage(msg);
      await _activateVariant(
          turnId: assistantMsg.turnId, activeUid: assistantUid);

      _emitToast('Ошибка: превышено время ожидания ответа сервера.');
    } catch (e) {
      if (_cancelledByUser || requestId != _activeRequestId) return;

      final msg = _messages[typingIndex].copyWith(
        content: 'Ошибка: $e',
        tokens: null,
        cost: null,
        isActiveVariant: true,
      );

      _messages[typingIndex] = msg;
      notifyListeners();
      await _saveMessage(msg);
      await _activateVariant(
          turnId: assistantMsg.turnId, activeUid: assistantUid);

      _emitToast('Ошибка: $e');
    } finally {
      if (requestId == _activeRequestId) {
        _cancelToken = null;
        _isLoading = false;
        notifyListeners();
      }
      _setGenerating(false);
    }
  }

  ChatMessage? _fallbackUserBeforeAssistant(ChatMessage a) {
    final ai = _messages.indexWhere((m) => m.uid == a.uid);
    if (ai <= 0) return null;
    for (int j = ai - 1; j >= 0; j--) {
      if (_messages[j].isUser) return _messages[j];
    }
    return null;
  }

}
