import 'dart:math' as math;

class TokenBudget {
  final int reserveTokens; // запас на служебные токены/метаданные
  final int minCompletionTokens; // минимально допустимый output

  const TokenBudget({
    this.reserveTokens = 1024,
    this.minCompletionTokens = 64,
  });

  /// Грубая оценка: 1 токен ~ 3 символа (консервативно).
  int estimateTokensRough(String text) {
    final chars = text.runes.length;
    return (chars / 3).ceil();
  }

  /// Сколько completion токенов можно запросить:
  /// - desired: “хочу столько”
  /// - hardCap: абсолютный потолок (например, для free)
  /// - contextLen: если известен, режем по контексту
  int maxCompletionTokens({
    required String promptText,
    required int desired,
    required int hardCap,
    required int? contextLen,
  }) {
    final desiredClamped = math.max(minCompletionTokens, desired);
    final cap = math.max(minCompletionTokens, hardCap);
    final wish = math.min(desiredClamped, cap);

    // если контекст неизвестен — возвращаем просто wish
    if (contextLen == null || contextLen <= 0) return wish;

    final promptTok = estimateTokensRough(promptText);
    final allowed = contextLen - reserveTokens - promptTok;

    if (allowed <= 0) return minCompletionTokens;

    return math.max(minCompletionTokens, math.min(wish, allowed));
  }

  /// Сколько токенов можно потратить на prompt,
  /// если хотим оставить место под completion.
  int maxPromptTokens({
    required int contextLen,
    required int completionTokens,
  }) {
    final budget = contextLen - reserveTokens - completionTokens;
    return math.max(0, budget);
  }
}
