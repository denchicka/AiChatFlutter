// AiProviderDetector - утилита для определения типа провайдера по API ключу
//
// Ответственность:
// - Определение провайдера (OpenRouter/VseGPT) по формату API ключа
// - Получение базового URL для API провайдера
// - Форматирование названий провайдеров для UI
//
// Логика определения:
// - OpenRouter: ключи начинаются с "sk-or-v1-"
// - VseGPT: ключи начинаются с "sk-or-vv-"
// - Если формат не распознан - возвращает null
//
// Примечание:
// - Базовые URL можно вынести в настройки, если понадобится гибкость

enum AiProviderType {
  openRouter,
  vseGpt,
}

class AiProviderDetector {
  /// Определяет тип провайдера по формату API ключа
  /// 
  /// Возвращает:
  /// - AiProviderType.openRouter если ключ начинается с "sk-or-v1-"
  /// - AiProviderType.vseGpt если ключ начинается с "sk-or-vv-"
  /// - null если формат не распознан
  static AiProviderType? detectProviderTypeFromApiKey(String apiKey) {
    final String trimmedApiKey = apiKey.trim();

    if (trimmedApiKey.startsWith('sk-or-v1-')) {
      return AiProviderType.openRouter;
    }

    if (trimmedApiKey.startsWith('sk-or-vv-')) {
      return AiProviderType.vseGpt;
    }

    return null;
  }

  /// Возвращает человекочитаемое название провайдера
  static String providerTitle(AiProviderType providerType) {
    switch (providerType) {
      case AiProviderType.openRouter:
        return 'OpenRouter';
      case AiProviderType.vseGpt:
        return 'VSEGPT';
    }
  }

  /// Возвращает базовый URL для API провайдера
  /// 
  /// Примечание: при необходимости можно вынести в настройки для гибкости
  static Uri defaultBaseUri(AiProviderType providerType) {
    switch (providerType) {
      case AiProviderType.openRouter:
        return Uri.parse('https://openrouter.ai/api/v1');

      case AiProviderType.vseGpt:
        // Вариант A (часто указывается у VseGPT для OpenAI-совместимого API)
        return Uri(
          scheme: 'https',
          host: 'api.vsegpt.ru',
          port: 6070,
          path: '/v1',
        );

      // Вариант B (альтернативный):
      // return Uri.parse('https://api.vsegpt.ru/v1');
    }
  }
}
