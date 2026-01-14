import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../widgets/top_toast.dart';
import 'code_highlighter.dart';

class MarkdownCodeBlockBuilder extends MarkdownElementBuilder {
  final ThemeData theme;
  final bool isUser;

  MarkdownCodeBlockBuilder({
    required this.theme,
    required this.isUser,
  });

  String? _extractLanguageFromClass(String? classAttr) {
    if (classAttr == null || classAttr.isEmpty) return null;
    final m = RegExp(r'language-([\w+-]+)').firstMatch(classAttr);
    return m?.group(1);
  }

  md.Element? _firstChildElement(md.Element parent, String tag) {
    final children = parent.children;
    if (children == null) return null;
    for (final c in children) {
      if (c is md.Element && c.tag == tag) return c;
    }
    return null;
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Обычно: <pre><code class="language-python">...</code></pre>
    final codeEl = _firstChildElement(element, 'code');

    final rawCode = (codeEl?.textContent ?? element.textContent).trimRight();

    final lang = _extractLanguageFromClass(
      codeEl?.attributes['class'] ?? element.attributes['class'],
    );

    return _CodeBlockCard(
      theme: theme,
      isUser: isUser,
      code: rawCode,
      language: lang,
    );
  }
}

class _CodeBlockCard extends StatelessWidget {
  final ThemeData theme;
  final bool isUser;
  final String code;
  final String? language;

  const _CodeBlockCard({
    required this.theme,
    required this.isUser,
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    final marked = (language == null || language!.isEmpty)
        ? code
        : '${CodeHighlighter.langMarker}${language!}'
            '${CodeHighlighter.langMarker}$code';

    final bg = isUser
        ? scheme.onPrimary.withValues(alpha: 0.14)
        : scheme.surfaceContainerHighest;

    final border = isUser
        ? scheme.onPrimary.withValues(alpha: 0.22)
        : scheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth, // КЛЮЧ: растягиваем блок на всю ширину
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Stack(
              children: [
                if (language != null && language!.isNotEmpty)
                  Positioned(
                    left: 10,
                    top: 8,
                    child: Text(
                      language!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton(
                    tooltip: 'Копировать код',
                    icon: const Icon(Icons.content_copy, size: 16),
                    color: scheme.onSurfaceVariant,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      TopToast.show(
                        context,
                        'Код скопирован',
                        type: TopToastType.success,
                        duration: const Duration(seconds: 1),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    (language != null && language!.isNotEmpty) ? 28 : 12,
                    12,
                    12,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      // КЛЮЧ: чтобы фон/ширина не схлопывались из-за горизонтального скролла
                      child: Text.rich(
                        CodeHighlighter(theme).format(marked),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
