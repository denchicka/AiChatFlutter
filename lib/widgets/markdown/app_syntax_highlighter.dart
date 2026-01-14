import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// Поддерживает язык из маркера в начале source:
/// L@NG!pythonL@NG!<реальный код>
/// (маркеры мы инжектим в Markdown перед рендером).
class CodeHighlighter extends SyntaxHighlighter {
  CodeHighlighter(this.theme);

  final ThemeData theme;

  static const String langMarker = 'L@NG!';

  TextStyle get _rootStyle => TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.35,
        color: theme.colorScheme.onSurface,
      );

  Map<String, TextStyle> get _styles {
    final cs = theme.colorScheme;

    TextStyle s(
      Color c, {
      FontWeight? w,
      FontStyle? fs,
    }) =>
        TextStyle(
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

      // common
      'keyword': keyword,
      'built_in': builtIn,
      'type': builtIn,
      'literal': keyword,
      'number': number,
      'regexp': string,
      'string': string,
      'subst': s(cs.onSurface),
      'symbol': s(cs.tertiary, w: FontWeight.w700),

      // names/titles
      'class': title,
      'function': title,
      'title': title,
      'params': s(cs.onSurface),

      // comments/meta
      'comment': comment,
      'doctag': comment,
      'meta': s(cs.onSurfaceVariant),
      'meta-keyword': keyword,
      'meta-string': string,

      // html/css-ish
      'section': title,
      'tag': keyword,
      'name': keyword,
      'attr': attr,
      'attribute': attr,
      'selector-tag': keyword,
      'selector-id': s(cs.secondary, w: FontWeight.w700),
      'selector-class': s(cs.secondary, w: FontWeight.w700),

      // misc
      'bullet': s(cs.primary, w: FontWeight.w700),
      'link': s(cs.primary),
      'quote': comment,

      // diffs
      'addition': s(cs.tertiary, w: FontWeight.w700),
      'deletion': s(cs.error, w: FontWeight.w700),
    };
  }

  @override
  TextSpan format(String source) {
    String? lang;

    // Считываем язык из маркера, если он был инжектнут заранее.
    if (source.startsWith(langMarker)) {
      final end = source.indexOf(langMarker, langMarker.length);
      if (end != -1) {
        lang = source.substring(langMarker.length, end);
        source = source.substring(end + langMarker.length);
      }
    }

    // highlight.parse поддерживает autoDetection + language
    final res = highlight.parse(
      source,
      language: lang,
      autoDetection: true,
    );

    final nodes = res.nodes ?? const <Node>[];
    return TextSpan(style: _rootStyle, children: _convert(nodes));
  }

  List<TextSpan> _convert(List<Node> nodes) {
    final spans = <TextSpan>[];

    for (final node in nodes) {
      if (node.value != null) {
        spans.add(TextSpan(text: node.value));
        continue;
      }

      final children = node.children;
      if (children == null || children.isEmpty) continue;

      final style = _resolveStyle(node.className);
      spans.add(TextSpan(style: style, children: _convert(children)));
    }

    return spans;
  }

  TextStyle? _resolveStyle(String? className) {
    if (className == null || className.trim().isEmpty) return null;

    // className иногда содержит несколько классов через пробел
    final parts = className.split(RegExp(r'\s+'));
    final map = _styles;

    for (final p in parts) {
      final st = map[p];
      if (st != null) return st;
    }

    return null;
  }
}
