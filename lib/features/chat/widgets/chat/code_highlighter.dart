import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:highlight/languages/dart.dart' as lang_dart;
import 'package:highlight/languages/python.dart' as lang_python;
import 'package:highlight/languages/javascript.dart' as lang_js;
import 'package:highlight/languages/json.dart' as lang_json;
import 'package:highlight/languages/bash.dart' as lang_bash;
import 'package:highlight/languages/yaml.dart' as lang_yaml;
import 'package:highlight/languages/xml.dart' as lang_xml;
import 'package:highlight/languages/css.dart' as lang_css;
import 'package:highlight/languages/sql.dart' as lang_sql;

/// Подсветка синтаксиса для блоков кода в Markdown
///
/// Реализует SyntaxHighlighter для использования в flutter_markdown.
/// Поддерживает следующие языки программирования:
/// - Dart, Python, JavaScript, JSON
/// - Bash/Shell, YAML, XML/HTML, CSS, SQL
///
/// Использует библиотеку highlight для парсинга и подсветки кода.
/// Стили применяются на основе цветовой схемы темы приложения.
class CodeHighlighter extends SyntaxHighlighter {
  /// Флаг инициализации языков (один раз для всего приложения)
  static bool _inited = false;

  /// Инициализирует языки программирования для подсветки синтаксиса
  ///
  /// Вызывается автоматически при первом использовании.
  /// Регистрирует все поддерживаемые языки в библиотеке highlight.
  static void _initOnce() {
    if (_inited) return;
    _inited = true;

    highlight.registerLanguage('dart', lang_dart.dart);
    highlight.registerLanguage('python', lang_python.python);
    highlight.registerLanguage('javascript', lang_js.javascript);
    highlight.registerLanguage('js', lang_js.javascript);
    highlight.registerLanguage('json', lang_json.json);
    highlight.registerLanguage('bash', lang_bash.bash);
    highlight.registerLanguage('sh', lang_bash.bash);
    highlight.registerLanguage('yaml', lang_yaml.yaml);
    highlight.registerLanguage('yml', lang_yaml.yaml);
    highlight.registerLanguage('xml', lang_xml.xml);
    highlight.registerLanguage('html', lang_xml.xml); // для простоты
    highlight.registerLanguage('css', lang_css.css);
    highlight.registerLanguage('sql', lang_sql.sql);
  }

  /// Создает экземпляр подсветки синтаксиса
  ///
  /// [theme] - тема приложения для получения цветов
  CodeHighlighter(this.theme);
  
  /// Тема приложения для стилизации кода
  final ThemeData theme;

  /// Маркер для указания языка в начале строки кода
  /// Формат: L@NG!языкL@NG!код
  static const String langMarker = 'L@NG!';

  /// Базовый стиль текста для кода (моноширинный шрифт)
  TextStyle get _rootStyle => TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface,
        shadows: const [],
      );

  /// Карта стилей для различных элементов кода
  ///
  /// Определяет цвета и начертания для:
  /// - Ключевых слов (keywords)
  /// - Встроенных функций (built_in)
  /// - Чисел (number)
  /// - Строк (string)
  /// - Комментариев (comment)
  /// - И других элементов синтаксиса
  ///
  /// Цвета берутся из цветовой схемы темы приложения.
  Map<String, TextStyle> get _styles {
    final cs = theme.colorScheme;

    TextStyle s(Color c, {FontWeight? w, FontStyle? fs}) => TextStyle(
          color: c,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.35,
          fontWeight: w,
          fontStyle: fs,
        );

    final keyword = s(cs.primary, w: FontWeight.w700);
    final builtIn = s(cs.secondary, w: FontWeight.w600);
    final number = s(cs.secondary, w: FontWeight.w700);
    final string = s(cs.tertiary, w: FontWeight.w600);
    final comment = s(cs.onSurfaceVariant, fs: FontStyle.italic);
    final title = s(cs.primary, w: FontWeight.w700);
    final attr = s(cs.secondary, w: FontWeight.w700);

    return <String, TextStyle>{
      'root': _rootStyle,
      'keyword': keyword,
      'built_in': builtIn,
      'type': builtIn,
      'literal': keyword,
      'number': number,
      'regexp': string,
      'string': string,
      'subst': s(cs.onSurface),
      'symbol': s(cs.tertiary, w: FontWeight.w700),
      'class': title,
      'function': title,
      'title': title,
      'params': s(cs.onSurface),
      'comment': comment,
      'doctag': comment,
      'meta': s(cs.onSurfaceVariant),
      'meta-keyword': keyword,
      'meta-string': string,
      'section': title,
      'tag': keyword,
      'name': keyword,
      'attr': attr,
      'attribute': attr,
      'selector-tag': keyword,
      'selector-id': s(cs.secondary, w: FontWeight.w700),
      'selector-class': s(cs.secondary, w: FontWeight.w700),
      'bullet': s(cs.primary, w: FontWeight.w700),
      'link': s(cs.primary),
      'quote': comment,
      'addition': s(cs.tertiary, w: FontWeight.w700),
      'deletion': s(cs.error, w: FontWeight.w700),
    };
  }

  /// Форматирует исходный код в TextSpan с подсветкой синтаксиса
  ///
  /// [source] - исходный код для форматирования
  /// Может содержать маркер языка в формате L@NG!языкL@NG!код
  ///
  /// Возвращает TextSpan с форматированным текстом и стилями.
  @override
  TextSpan format(String source) {
    _initOnce();
    String? lang;

    if (source.startsWith(langMarker)) {
      final end = source.indexOf(langMarker, langMarker.length);
      if (end != -1) {
        lang = source.substring(langMarker.length, end);
        source = source.substring(end + langMarker.length);
      }
    }

    final res = highlight.parse(
      source,
      language: lang,
      autoDetection: true,
    );

    final nodes = res.nodes ?? const <Node>[];
    return TextSpan(style: _rootStyle, children: _convert(nodes));
  }

  /// Преобразует узлы дерева разбора в список TextSpan
  ///
  /// Рекурсивно обходит дерево узлов, создавая TextSpan для каждого узла
  /// с соответствующими стилями на основе класса узла.
  ///
  /// [nodes] - список узлов дерева разбора от highlight
  /// Возвращает список TextSpan для отображения
  List<TextSpan> _convert(List<Node> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node.value != null) {
        spans.add(TextSpan(text: node.value));
        continue;
      }
      final children = node.children;
      if (children == null || children.isEmpty) continue;
      spans.add(TextSpan(
        style: _resolveStyle(node.className),
        children: _convert(children),
      ));
    }
    return spans;
  }

  /// Определяет стиль текста на основе класса узла
  ///
  /// Класс может содержать несколько классов через пробел.
  /// Возвращает первый найденный стиль из карты стилей.
  ///
  /// [className] - строка с классами узла (например, "keyword", "string comment")
  /// Возвращает TextStyle для класса или null, если стиль не найден
  TextStyle? _resolveStyle(String? className) {
    if (className == null || className.trim().isEmpty) return null;
    final parts = className.split(RegExp(r'\s+'));
    for (final p in parts) {
      final st = _styles[p];
      if (st != null) return st;
    }
    return null;
  }
}
