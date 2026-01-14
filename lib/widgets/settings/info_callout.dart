import 'package:flutter/material.dart';

/// Виджет для отображения информационного блока с иконкой
///
/// Используется для показа важной информации, подсказок и инструкций
/// в настройках приложения. Имеет стилизованный вид с иконкой слева
/// и текстом справа.
///
/// Пример использования:
/// ```dart
/// InfoCallout(
///   icon: Icons.info_outline,
///   title: 'Важно',
///   body: Text('Текст подсказки'),
/// )
/// ```
class InfoCallout extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;

  const InfoCallout({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                DefaultTextStyle(
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  child: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Утилитный класс для отображения модальных окон с информацией
///
/// Предоставляет два метода:
/// - [show] - показывает произвольный виджет в модальном окне
/// - [showSteps] - показывает список шагов в модальном окне
///
/// Окна открываются снизу экрана (bottom sheet) с возможностью
/// прокрутки содержимого.
class InfoSheet {
  /// Показывает модальное окно с произвольным содержимым
  ///
  /// [context] - контекст для отображения модального окна
  /// [title] - заголовок окна
  /// [child] - виджет с содержимым (будет прокручиваемым)
  /// [okText] - текст на кнопке закрытия (по умолчанию "Понятно")
  ///
  /// Возвращает Future, который завершается при закрытии окна.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Widget child,
    String okText = 'Понятно',
  }) {
    final scheme = Theme.of(context).colorScheme;

    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: child)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    // важно: закрываем через sheetCtx
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: Text(okText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Показывает модальное окно со списком шагов
  ///
  /// [context] - контекст для отображения модального окна
  /// [title] - заголовок окна
  /// [steps] - список строк, каждая строка - один шаг (будет отмечен маркером •)
  /// [footer] - опциональный текст внизу списка шагов
  /// [okText] - текст на кнопке закрытия (по умолчанию "Понятно")
  ///
  /// Возвращает Future, который завершается при закрытии окна.
  static Future<void> showSteps(
    BuildContext context, {
    required String title,
    required List<String> steps,
    String? footer,
    String okText = 'Понятно',
  }) {
    return show(
      context,
      title: title,
      okText: okText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...steps.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(
              footer,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
