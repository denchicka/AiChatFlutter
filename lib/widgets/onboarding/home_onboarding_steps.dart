import 'package:flutter/material.dart';
import 'onboarding_overlay.dart';
import 'screen_onboarding_wrapper.dart';

/// Шаги обучения для HomeScreen
class HomeOnboardingSteps {
  static List<OnboardingStep> createSteps({
    required GlobalKey statusCardKey,
    required GlobalKey chatTileKey,
    required GlobalKey providerTileKey,
    required GlobalKey statsTileKey,
    required GlobalKey chartTileKey,
    required GlobalKey settingsTileKey,
  }) {
    return [
      OnboardingStep(
        key: statusCardKey,
        title: 'Статус системы',
        description:
            'Здесь отображается текущий статус вашего подключения к провайдеру AI и состояние авторизации.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: chatTileKey,
        title: 'Чат с AI',
        description:
            'Основной экран для общения с искусственным интеллектом. Здесь вы можете задавать вопросы и получать ответы.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: providerTileKey,
        title: 'Настройка провайдера',
        description:
            'Настройте API ключ для OpenRouter или VseGPT. Это необходимо для работы с AI моделями.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: statsTileKey,
        title: 'Статистика токенов',
        description:
            'Просматривайте детальную статистику использования токенов по каждой модели.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: chartTileKey,
        title: 'График расходов',
        description:
            'Визуализация расходов на использование AI по дням. Помогает отслеживать бюджет.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: settingsTileKey,
        title: 'Настройки',
        description:
            'Настройте уведомления, тему оформления, обновления и другие параметры приложения.',
        position: TooltipPosition.bottom,
      ),
    ];
  }
}
