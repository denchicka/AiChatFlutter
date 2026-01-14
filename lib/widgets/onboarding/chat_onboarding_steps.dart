import 'package:flutter/material.dart';
import 'onboarding_overlay.dart';
import 'screen_onboarding_wrapper.dart';

/// Шаги обучения для ChatScreen
class ChatOnboardingSteps {
  static List<OnboardingStep> createSteps({
    required GlobalKey modelSelectorKey,
    required GlobalKey balanceKey,
    required GlobalKey messagesListKey,
    required GlobalKey inputAreaKey,
    required GlobalKey menuKey,
  }) {
    return [
      OnboardingStep(
        key: modelSelectorKey,
        title: 'Выбор модели AI',
        description:
            'Нажмите здесь, чтобы выбрать модель искусственного интеллекта. Доступны различные модели с разными возможностями и стоимостью.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: balanceKey,
        title: 'Баланс',
        description:
            'Здесь отображается ваш текущий баланс. Следите за расходом средств при использовании платных моделей.',
        position: TooltipPosition.bottom,
      ),
      OnboardingStep(
        key: messagesListKey,
        title: 'История сообщений',
        description:
            'Здесь отображаются все ваши сообщения и ответы AI. Поддерживается форматирование markdown, код и формулы LaTeX.',
        position: TooltipPosition.top,
      ),
      OnboardingStep(
        key: inputAreaKey,
        title: 'Поле ввода',
        description:
            'Введите ваше сообщение здесь. Нажмите Enter для отправки, Shift+Enter для новой строки. Используйте кнопку меню для дополнительных функций.',
        position: TooltipPosition.top,
      ),
      OnboardingStep(
        key: menuKey,
        title: 'Дополнительные функции',
        description:
            'Меню с дополнительными опциями: обновление, аналитика, экспорт истории, очистка чата и другие функции.',
        position: TooltipPosition.bottom,
      ),
    ];
  }
}
