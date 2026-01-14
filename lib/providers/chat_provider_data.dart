part of 'chat_provider.dart';

mixin _ChatProviderData on _ChatProviderBase {
  bool _inRange(DateTime ts, DateTime? fromInclusive, DateTime? toExclusive) {
    if (fromInclusive != null && ts.isBefore(fromInclusive)) return false;
    if (toExclusive != null && !ts.isBefore(toExclusive)) return false;
    return true;
  }

  /// Берём только AI-сообщения (где есть стоимость/токены), т.к. cost логично привязан к ответу модели.
  /// Если у тебя cost может быть null — такие сообщения пропускаем.
  Iterable<ChatMessage> _assistantMessagesInRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter, // ProviderIds.*
    bool onlyActiveVariants = true,
    bool requireMetrics =
        false, // если нужно отбрасывать ответы без tokens/cost
  }) sync* {
    for (final m in _messages) {
      if (m.isUser) continue;

      // убираем плейсхолдеры/пустое
      final txt = m.content.trim();
      if (txt.isEmpty || txt == '…') continue;

      if (onlyActiveVariants && !m.isActiveVariant) continue;

      final ts = m.createdAt;
      if (!_inRange(ts, fromInclusive, toExclusive)) continue;

      // infer providerId для старых сообщений
      final inferredProviderId = ProviderUtils.inferProviderIdFromMessage(
        providerId: m.providerId,
        pricedAsVseGpt: m.pricedAsVseGpt,
      );

      if (providerFilter != null && inferredProviderId != providerFilter) {
        continue;
      }

      if (requireMetrics && (m.tokens == null && m.cost == null)) continue;

      yield m;
    }
  }

  ModelUsage totalsForRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter,
  }) {
    int req = 0;
    int tokens = 0;
    double cost = 0.0;

    for (final m in _assistantMessagesInRange(
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
      providerFilter: providerFilter,
      onlyActiveVariants: true,
      requireMetrics: false,
    )) {
      req += 1;
      tokens += (m.tokens ?? 0);
      cost += (m.cost ?? 0.0);
    }

    return ModelUsage(requests: req, tokens: tokens, cost: cost);
  }

  @override
  Map<String, ModelUsage> usageByModelForRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter,
  }) {
    final accReq = <String, int>{};
    final accTok = <String, int>{};
    final accCost = <String, double>{};

    for (final m in _assistantMessagesInRange(
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
      providerFilter: providerFilter,
      onlyActiveVariants: true,
      requireMetrics: false,
    )) {
      final id =
          (m.modelId == null || m.modelId!.isEmpty) ? 'unknown' : m.modelId!;
      accReq[id] = (accReq[id] ?? 0) + 1;
      accTok[id] = (accTok[id] ?? 0) + (m.tokens ?? 0);
      accCost[id] = (accCost[id] ?? 0.0) + (m.cost ?? 0.0);
    }

    final out = <String, ModelUsage>{};
    for (final id in accReq.keys) {
      out[id] = ModelUsage(
        requests: accReq[id] ?? 0,
        tokens: accTok[id] ?? 0,
        cost: accCost[id] ?? 0.0,
      );
    }
    return out;
  }

  @override
  ChatMessage? _userMessageForTurn(String turnId) {
    for (final m in _messages) {
      if (m.isUser && m.turnId == turnId) return m;
    }
    return null;
  }

  @override
  List<ChatMessage> _buildContextUpToTurn(String targetTurnId) {
    // 1) user по turn
    final userByTurn = <String, ChatMessage>{};
    // 2) активный assistant по turn
    final activeAiByTurn = <String, ChatMessage>{};

    for (final m in _messages) {
      if (m.isUser) {
        userByTurn.putIfAbsent(m.turnId, () => m);
      } else {
        // игнорим плейсхолдеры и пустые
        final txt = m.content.trim();
        if (txt.isEmpty || txt == '…') continue;
        if (m.isActiveVariant) {
          activeAiByTurn[m.turnId] = m;
        }
      }
    }

    final turns = userByTurn.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final out = <ChatMessage>[];
    for (final userMsg in turns) {
      out.add(userMsg);
      if (userMsg.turnId == targetTurnId) break;

      final ai = activeAiByTurn[userMsg.turnId];
      if (ai != null) out.add(ai);
    }
    return out;
  }

  @override
  String _buildPseudoChatPrompt(List<ChatMessage> ctx) {
    final b = StringBuffer();
    b.writeln('Продолжи диалог и ответь как ассистент.');
    b.writeln('');

    for (final m in ctx) {
      final role = m.isUser ? 'User' : 'Assistant';
      b.writeln('$role: ${m.content}');
      b.writeln('');
    }

    b.write('Assistant:');
    return b.toString();
  }

  @override
  Future<void> _activateVariant({
    required String turnId,
    required String activeUid,
  }) async {
    bool changed = false;

    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.isUser) continue;
      if (m.turnId != turnId) continue;

      final shouldBeActive = (m.uid == activeUid);
      if (m.isActiveVariant != shouldBeActive) {
        _messages[i] = m.copyWith(isActiveVariant: shouldBeActive);
        changed = true;
      }
    }

    if (changed) notifyListeners();
    await _db.setActiveAssistantVariant(turnId: turnId, activeUid: activeUid);
  }

  /// Детализация по дням: cost/tokens/requests вместе
  @override
  List<DailyAggregate> dailyAggregatesForRange({
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? providerFilter,
  }) {
    final req = <DateTime, int>{};
    final tok = <DateTime, int>{};
    final cost = <DateTime, double>{};

    for (final m in _assistantMessagesInRange(
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
      providerFilter: providerFilter,
      onlyActiveVariants: true,
      requireMetrics: false,
    )) {
      final day = _dayStart(m.createdAt);

      req[day] = (req[day] ?? 0) + 1;
      tok[day] = (tok[day] ?? 0) + (m.tokens ?? 0);
      cost[day] = (cost[day] ?? 0.0) + (m.cost ?? 0.0);
    }

    final days = req.keys.toList()..sort((a, b) => a.compareTo(b));
    return days
        .map((d) => DailyAggregate(
              day: d,
              requests: req[d] ?? 0,
              tokens: tok[d] ?? 0,
              cost: cost[d] ?? 0.0,
            ))
        .toList();
  }

  /// Удобный метод: статистика по моделям за один день
  Map<String, ModelUsage> usageByModelForDay(DateTime day,
      {String? providerFilter}) {
    final start = _dayStart(day);
    final end = start.add(const Duration(days: 1));
    return usageByModelForRange(
      fromInclusive: start,
      toExclusive: end,
      providerFilter: providerFilter,
    );
  }

  // Метод загрузки истории сообщений
  @override
  Future<void> _loadHistory() async {
    try {
      // Получение сообщений из базы данных
      final messages = await _db.getMessages(limit: 1000);
      // Очистка текущего списка и добавление новых сообщений
      _messages.clear();
      _messages.addAll(messages);
      // Уведомление слушателей об изменениях
      notifyListeners();
    } catch (e, stackTrace) {
      // Логирование ошибок загрузки истории с полной информацией
      _log('Error loading history: $e');
      _log('Stack trace: $stackTrace');
      // Не прерываем работу приложения, просто логируем ошибку
      // UI продолжит работать с пустым списком сообщений
    }
  }

  @override
  Future<void> _repairMissingProviderIds() async {
    bool changed = false;

    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      // providerId сейчас non-nullable, но могли остаться старые записи с unknown/пустым
      final hasProvider = m.providerId.isNotEmpty && m.providerId != ProviderIds.unknown;
      if (hasProvider) continue;

      final inferred = ProviderUtils.inferProviderIdFromMessage(
        providerId: m.providerId,
        pricedAsVseGpt: m.pricedAsVseGpt,
      );

      final patched = m.copyWith(providerId: inferred);
      _messages[i] = patched;
      changed = true;

      unawaited(_saveMessage(
          patched)); // обновит запись по uid (если так реализовано в БД)
    }

    if (changed) notifyListeners();
  }

  // Метод сохранения сообщения в базу данных
  @override
  Future<void> _saveMessage(ChatMessage message) async {
    try {
      // Сохранение сообщения в базу данных
      await _db.saveMessage(message);
    } catch (e, stackTrace) {
      // Логирование ошибок сохранения сообщения с полной информацией
      _log('Error saving message: $e');
      _log('Stack trace: $stackTrace');
      // Не прерываем работу приложения - сообщение останется в памяти
      // но не будет сохранено в БД
    }
  }

  @override
  double? _tryParseDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  @override
  int? _normTokens(dynamic v) {
    final t = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '');
    if (t == null || t <= 0) return null;
    return t;
  }

  @override
  double? _calcCostForModel({
    required String modelId,
    required bool pricedAsVseGpt,
    required int promptTokens,
    required int completionTokens,
    double? totalCostFromApi,
  }) {
    final model = _availableModels.firstWhere(
      (m) => m['id'] == modelId,
      orElse: () => <String, dynamic>{
        'pricing': <String, dynamic>{'prompt': null, 'completion': null},
      },
    );

    final pricing = ModelPricing.fromMap(
      model['pricing'] as Map<String, dynamic>?,
    );

    final costCalculator = const CostCalculator();
    return costCalculator.calcCost(
      pricedAsVseGpt: pricedAsVseGpt,
      pricing: pricing,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalCostFromApi: totalCostFromApi,
    );
  }

}
