import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Виджет для отображения кликабельного текста-ссылки
///
/// Отображает текст с подчеркиванием и цветом primary из темы.
/// При нажатии открывает URL во внешнем приложении (браузере).
///
/// Используется для отображения ссылок в информационных блоках,
/// например, ссылки на BotFather, документацию и т.д.
class LinkText extends StatelessWidget {
  final String text;
  final String url;

  const LinkText({super.key, required this.text, required this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text(
          text,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationThickness: 1.2,
          ),
        ),
      ),
    );
  }
}
