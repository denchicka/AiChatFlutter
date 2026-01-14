// ProviderUtils - утилиты для работы с провайдерами
//
// Ответственность:
// - Конвертация между ProviderIds (строки) и AiProviderType (enum)
// - Определение провайдера из различных источников
// - Получение человекочитаемых названий провайдеров
//
// Использование:
// - В ChatProvider для определения провайдера из сообщений
// - В UI для отображения названий провайдеров
//
// Примеры использования:
//
// ```dart
// // Определение провайдера из сообщения (с fallback на pricedAsVseGpt)
// final providerId = ProviderUtils.inferProviderIdFromMessage(
//   providerId: message.providerId,
//   pricedAsVseGpt: message.pricedAsVseGpt,
// );
// // Результат: "openrouter", "vsegpt" или "unknown"
//
// // Конвертация между типами
// final providerType = ProviderUtils.providerTypeFromId("openrouter");
// // Результат: AiProviderType.openRouter или null
//
// final providerId = ProviderUtils.providerIdFromType(AiProviderType.vseGpt);
// // Результат: "vsegpt"
//
// // Получение человекочитаемого названия
// final label = ProviderUtils.providerLabel("openrouter");
// // Результат: "OpenRouter"
// ```

import '../../../../analytics/provider_ids.dart';
import '../../../../features/auth/domain/ai_provider_detector.dart';

class ProviderUtils {
  /// Определяет провайдер из providerId строки
  /// 
  /// Возвращает AiProviderType или null если провайдер unknown
  static AiProviderType? providerTypeFromId(String providerId) {
    switch (providerId) {
      case ProviderIds.openrouter:
        return AiProviderType.openRouter;
      case ProviderIds.vsegpt:
        return AiProviderType.vseGpt;
      default:
        return null;
    }
  }

  /// Конвертирует AiProviderType в ProviderIds строку
  static String providerIdFromType(AiProviderType providerType) {
    return switch (providerType) {
      AiProviderType.openRouter => ProviderIds.openrouter,
      AiProviderType.vseGpt => ProviderIds.vsegpt,
    };
  }

  /// Определяет провайдер из сообщения (используя providerId или pricedAsVseGpt как fallback)
  /// 
  /// Используется для старых сообщений, где providerId может быть пустым
  static String inferProviderIdFromMessage({
    required String providerId,
    required bool? pricedAsVseGpt,
  }) {
    if (providerId.isNotEmpty && providerId != ProviderIds.unknown) {
      return providerId;
    }

    if (pricedAsVseGpt == true) {
      return ProviderIds.vsegpt;
    }

    if (pricedAsVseGpt == false) {
      return ProviderIds.openrouter;
    }

    return ProviderIds.unknown;
  }

  /// Получает человекочитаемое название провайдера из providerId
  static String providerLabel(String providerId) {
    final providerType = providerTypeFromId(providerId);
    if (providerType == null) {
      return 'Unknown';
    }
    return AiProviderDetector.providerTitle(providerType);
  }
}
