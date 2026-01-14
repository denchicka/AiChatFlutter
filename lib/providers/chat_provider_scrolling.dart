part of 'chat_provider.dart';

mixin _ChatProviderScrolling on _ChatProviderBase {
  /// ChatScreen будет забирать это значение и скроллить список
  int? consumePendingScrollIndex() {
    final v = _pendingScrollIndex;
    _pendingScrollIndex = null;
    return v;
  }

  void requestScrollToIndex(int index) {
    if (_messages.isEmpty) return;

    final safe = index.clamp(0, _messages.length - 1);
    _pendingScrollIndex = safe;
    notifyListeners();
  }

  void requestScrollToUid(String uid, {bool emitToast = false}) {
    final idx = _messages.indexWhere((m) => m.uid == uid);
    if (idx < 0) {
      _emitToast('Сообщение не найдено');
      return;
    }
    requestScrollToIndex(idx);
  }

  /// Возвращает true если нашли, иначе false (и можно показать toast)
  bool requestScrollToMessage({
    DateTime? day,
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? modelId,
    String? providerId,
    bool preferMaxCost = true,
    bool emitToast = true,
  }) {
    final idx = _findMessageIndex(
      day: day,
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
      modelId: modelId,
      providerId: providerId,
      preferMaxCost: preferMaxCost,
    );

    if (idx == null) {
      if (emitToast) _emitToast('Сообщение не найдено');
      return false;
    }

    _pendingScrollIndex = idx;
    notifyListeners();
    return true;
  }

  int? _findMessageIndex({
    DateTime? day,
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? modelId,
    String? providerId,
    required bool preferMaxCost,
  }) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    int? bestIdx;
    double bestScore = -1;

    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];

      // обычно токены/стоимость на ответе ИИ
      if (m.isUser) continue;

      final t = m.createdAt;

      if (day != null && !sameDay(t, day)) continue;
      if (fromInclusive != null && t.isBefore(fromInclusive)) continue;
      if (toExclusive != null && !t.isBefore(toExclusive)) continue;

      if (modelId != null && (m.modelId ?? '') != modelId) continue;
      if (providerId != null && m.providerId != providerId) continue;

      final cost = (m.cost ?? 0.0);
      final tokens = (m.tokens ?? 0);

      // если нет метрик — пропускаем
      if ((m.cost == null) && (m.tokens == null)) continue;

      if (!preferMaxCost) return i;

      // скоринг: сначала стоимость, потом токены
      final score = cost * 1e9 + tokens.toDouble();
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  bool requestScrollToDay(DateTime day, {bool emitToast = false}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final idx = _messages.indexWhere((m) {
      final t = m.createdAt;
      return !t.isBefore(start) && t.isBefore(end);
    });

    if (idx < 0) {
      if (emitToast) {
        final dd = day.day.toString().padLeft(2, '0');
        final mm = day.month.toString().padLeft(2, '0');
        _emitToast('Нет сообщений за $dd.$mm.${day.year}');
      }
      return false;
    }

    requestScrollToIndex(idx);
    return true;
  }

}
