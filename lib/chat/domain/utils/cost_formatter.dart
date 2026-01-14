// CostFormatter - утилитный класс для форматирования стоимости
//
// Ответственность:
// - Единообразное форматирование стоимости для всех провайдеров
// - Поддержка разных валют (USD, RUB)
// - Обработка специальных случаев (FREE, tiny costs)
//
// Использование:
// - В UI компонентах для отображения стоимости
// - В аналитике для форматирования статистики
//
// Примеры использования:
//
// ```dart
// // Форматирование стоимости для сообщения в чате
// final costText = CostFormatter.formatCost(
//   message.cost,
//   providerId: message.providerId,
// );
// // Результат: "0.123$", "0.456₽", "FREE", "<0.0001$" и т.д.
//
// // Форматирование для аналитики с фильтром провайдера
// final costText = CostFormatter.formatCostForProvider(
//   totals.cost,
//   pf: ProviderFilter.openrouter,
// );
// // Результат: "$0.123", "FREE", "<$0.0001" и т.д.
// ```

import '../../../../analytics/provider_ids.dart';
import '../../../../features/auth/domain/ai_provider_detector.dart';

// Импортируем ProviderFilter из analytics_controls для использования в formatCostForProvider
import '../../../../widgets/analytics/analytics_controls.dart' show ProviderFilter;

class CostFormatter {
  static const double kTinyCost = 0.0001;

  /// Форматирует стоимость для отображения в UI
  /// 
  /// Параметры:
  /// - cost: стоимость (может быть null)
  /// - providerId: идентификатор провайдера (ProviderIds.*)
  /// 
  /// Возвращает:
  /// - "FREE" если cost == 0.0 и провайдер не VseGPT и не unknown
  /// - "<0.0001$" или "<0.0001₽" для очень маленьких сумм
  /// - "X.XXX$" или "X.XXX₽" для обычных сумм
  /// - "X.XXX" для unknown провайдера
  static String formatCost(double? cost, {required String providerId}) {
    if (cost == null) return '';

    final providerType = _providerIdToType(providerId);
    final isVse = providerType == AiProviderType.vseGpt;
    final isUnknown = providerType == null;

    // FREE: не привязываем к списку моделей текущего провайдера,
    // чтобы после переключения провайдера FREE не "ломался" у старых сообщений.
    final isFree = !isVse && !isUnknown && cost == 0.0;

    if (isFree) {
      return 'FREE';
    }

    if (cost.abs() < kTinyCost) {
      if (isUnknown) {
        return '<0.0001';
      }
      return isVse ? '<0.0001₽' : '<0.0001\$';
    }

    if (isUnknown) {
      return cost.toStringAsFixed(3);
    }

    return isVse
        ? '${cost.toStringAsFixed(3)}₽'
        : '${cost.toStringAsFixed(3)}\$';
  }

  /// Форматирует стоимость для аналитики с фильтром провайдера
  /// 
  /// Используется в UsagePanel и других аналитических виджетах
  static String formatCostForProvider(double cost, {required ProviderFilter pf}) {
    if (pf == ProviderFilter.openrouter) {
      if (cost == 0.0) return 'FREE';
      if (cost.abs() < kTinyCost) return '<\$0.0001';
      // Для больших значений используем компактный формат
      if (cost >= 1000) {
        return '\$${(cost / 1000).toStringAsFixed(2)}K';
      }
      if (cost >= 100) {
        return '\$${cost.toStringAsFixed(2)}';
      }
      return '\$${cost.toStringAsFixed(3)}';
    }

    if (pf == ProviderFilter.vsegpt) {
      if (cost.abs() < kTinyCost) return '<0.0001₽';
      // Для больших значений используем компактный формат
      if (cost >= 1000) {
        return '${(cost / 1000).toStringAsFixed(2)}K₽';
      }
      if (cost >= 100) {
        return '${cost.toStringAsFixed(2)}₽';
      }
      return '${cost.toStringAsFixed(3)}₽';
    }

    if (cost.abs() < kTinyCost) return '<0.0001';
    // Для больших значений используем компактный формат
    if (cost >= 1000) {
      return '${(cost / 1000).toStringAsFixed(2)}K';
    }
    if (cost >= 100) {
      return cost.toStringAsFixed(2);
    }
    return cost.toStringAsFixed(3);
  }

  /// Конвертирует ProviderIds строку в AiProviderType
  static AiProviderType? _providerIdToType(String providerId) {
    switch (providerId) {
      case ProviderIds.openrouter:
        return AiProviderType.openRouter;
      case ProviderIds.vsegpt:
        return AiProviderType.vseGpt;
      default:
        return null;
    }
  }
}

