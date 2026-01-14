part of 'chat_screen.dart';

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<ChatMessage> messages;
  final int index;
  final VoidCallback? onRequestScrollToBottom;

  const _MessageBubble({
    required this.message,
    required this.messages,
    required this.index,
    this.onRequestScrollToBottom,
  });

  // Latex extensions
  static final md.ExtensionSet _extLatex = md.ExtensionSet(
    md.ExtensionSet.gitHubFlavored.blockSyntaxes + [LatexBlockSyntax()],
    md.ExtensionSet.gitHubFlavored.inlineSyntaxes + [LatexInlineSyntax()],
  );

  static final md.ExtensionSet _extPlain = md.ExtensionSet.gitHubFlavored;

  bool _hasLatex(String s) =>
      s.contains(r'$') || s.contains(r'\(') || s.contains(r'\[');

  MarkdownStyleSheet _sheet(ThemeData theme, bool isUser) {
    final scheme = theme.colorScheme;

    // inline code (`like this`)
    final inlineCodeBg = isUser
        ? scheme.onPrimary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.85);

    final inlineCodeFg = scheme.onSurface;

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        color: isUser ? scheme.onPrimary : scheme.onSurface,
        fontSize: 13,
        height: 1.35,
      ),
      a: TextStyle(
        color: isUser ? scheme.onPrimary : scheme.primary,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        color: inlineCodeFg,
        fontFamily: 'monospace',
        fontSize: 12.5,
        backgroundColor: inlineCodeBg,
      ),
      // ВАЖНО: codeblock рисует наш MarkdownCodeBlockBuilder через builders['pre']
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
      blockquoteDecoration: BoxDecoration(
        color: (isUser ? scheme.onPrimary : scheme.surfaceContainerHighest)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: (isUser ? scheme.onPrimary : scheme.primary)
                .withValues(alpha: 0.55),
            width: 3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget actionTooltip({
      required String tooltipText,
      required Widget child,
    }) {
      return Tooltip(
        message: tooltipText,
        triggerMode: TooltipTriggerMode.longPress,
        waitDuration: const Duration(milliseconds: 350),
        showDuration: const Duration(seconds: 2),
        child: Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          child: child,
        ),
      );
    }

    final scheme = theme.colorScheme;

    final metaStyle = TextStyle(color: scheme.onSurfaceVariant, fontSize: 11);

    final bubbleMaxWidth = MediaQuery.of(context).size.width * 0.75;

    final rawText = message.cleanContent;

    // Это то, что показываем в UI (там появятся $...$ для формул)
    final text = _autoLatexifyMarkdown(rawText);

    final hasLatex = _hasLatex(text);

    final latexOnlyRaw =
        hasLatex ? extractLatexFormulas(text) : const <String>[];
    final latexOnly = latexOnlyRaw
        .map(_normalize)
        .where((s) => _looksRenderableAsMath(s) && !_isSinglePlainSymbol(s))
        .toList();
    final isTyping = !message.isUser && text.trim() == '…';

    String two(int n) => n.toString().padLeft(2, '0');
    final t = message.createdAt;
    final timeText = '${two(t.hour)}:${two(t.minute)}';

    final timeInBubbleStyle = TextStyle(
      fontSize: 10,
      height: 1.0,
      color: message.isUser
          ? scheme.onPrimary.withValues(alpha: 0.75)
          : scheme.onSurfaceVariant.withValues(alpha: 0.85),
    );

    void snack(String msg) {
      TopToast.show(context, msg, type: TopToastType.info);
    }

    Widget copyLatexButton() {
      return actionTooltip(
        tooltipText: 'Копировать LaTeX',
        child: IconButton(
          icon: const Icon(Icons.functions, size: 16),
          color: scheme.onSurfaceVariant,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: null,
          onPressed: latexOnly.isEmpty
              ? null
              : () async {
                  final payload = latexOnly.join('\n\n').trim();
                  try {
                    await Clipboard.setData(ClipboardData(text: payload));
                  } catch (_) {
                    if (!context.mounted) return;
                    TopToast.show(context, 'Не удалось скопировать LaTeX',
                        type: TopToastType.error);
                    return;
                  }
                  if (!context.mounted) return;
                  TopToast.show(context, 'LaTeX скопирован',
                      type: TopToastType.success,
                      duration: const Duration(seconds: 1));
                },
        ),
      );
    }

    Widget buildMarkdown({required bool isUser}) {
      final baseBuilders = <String, MarkdownElementBuilder>{
        'pre': MarkdownCodeBlockBuilder(theme: theme, isUser: isUser),
      };

      final latexBuilders = hasLatex
          ? <String, MarkdownElementBuilder>{
              'latex': _CopyableLatexMarkdownBuilder(isUser: isUser),
            }
          : const <String, MarkdownElementBuilder>{};

      return SelectionArea(
        child: MarkdownBody(
          data: text,
          selectable: false, // КЛЮЧ: selection делаем через SelectionArea
          onTapLink: (t, href, title) async {
            if (href == null) return;
            final uri = Uri.tryParse(href);
            if (uri == null) {
              snack('Некорректная ссылка');
              return;
            }
            try {
              final ok =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!context.mounted) return;
              if (!ok) snack('Не удалось открыть ссылку');
            } catch (_) {
              snack('Ошибка открытия ссылки');
            }
          },
          extensionSet: hasLatex ? _extLatex : _extPlain,
          builders: {...baseBuilders, ...latexBuilders},
          styleSheet: _sheet(theme, isUser),
        ),
      );
    }

    Widget content;
    if (isTyping) {
      // ВАЖНО: убираем декор у TypingDots, потому что пузырь уже рисует фон/радиус
      content = const TypingDots(dotSize: 6, spacing: 6, decorated: false);
    } else {
      // Рендерим markdown и для user, и для assistant -> backticks и блоки кода работают везде
      final shouldCollapse =
          !message.isUser && text.length > 1200; // порог можно подогнать
      content = ExpandableMessageBody(
        enabled: shouldCollapse,
        collapsedMaxHeight: 260,
        child: buildMarkdown(isUser: message.isUser),
      );
    }

    Widget copyButton() {
      return actionTooltip(
        tooltipText: 'Копировать текст',
        child: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          color: scheme.onSurfaceVariant,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: null, // ВАЖНО: не используем tooltip: у IconButton
          onPressed: () async {
            final textToCopyRaw = message.cleanContent;
            final textToCopy = markdownToPlainText(textToCopyRaw);

            try {
              await Clipboard.setData(ClipboardData(text: textToCopy));
            } catch (_) {
              if (!context.mounted) return;
              TopToast.show(context, 'Не удалось скопировать',
                  type: TopToastType.error);
              return;
            }

            if (!context.mounted) return;
            TopToast.show(
              context,
              'Текст скопирован',
              type: TopToastType.success,
              duration: const Duration(seconds: 1),
            );
          },
        ),
      );
    }

    Widget regenerateButton() {
      final isLoading = context.watch<ChatProvider>().isLoading;

      return actionTooltip(
        tooltipText: 'Повторить ответ',
        child: IconButton(
          icon: const Icon(Icons.refresh, size: 16),
          color: scheme.onSurfaceVariant,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: null,
          onPressed: isLoading
              ? null
              : () {
                  context.read<ChatProvider>().regenerateAnswerFor(message);
                  onRequestScrollToBottom?.call();
                },
        ),
      );
    }

    Widget actionButtonsRow() {
      final buttons = <Widget>[];
      if (!message.isUser) {
        buttons.add(regenerateButton());
      }
      if (latexOnly.isNotEmpty) {
        buttons.add(copyLatexButton());
      }
      buttons.add(copyButton());

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            buttons[i],
          ],
        ],
      );
    }

    return RepaintBoundary(
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: message.isUser
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 22),
                    child: content,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 6,
                    child: IgnorePointer(
                      child: Text(timeText, style: timeInBubbleStyle),
                    ),
                  ),
                ],
              ),
            ),

            // meta row (копировать/токены/стоимость/модель)
            // meta row (копировать/токены/стоимость/модель)
            if (!isTyping)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                  child: Wrap(
                    alignment: message.isUser
                        ? WrapAlignment.end
                        : WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // SETTINGS: показывать токены
                      if (context.select<SettingsProvider, bool>(
                              (s) => s.showTokensInChat) &&
                          message.tokens != null)
                        Text('Токенов: ${message.tokens}', style: metaStyle),

                      // SETTINGS: показывать стоимость
                      if (context.select<SettingsProvider, bool>(
                          (s) => s.showCostInChat))
                        Builder(builder: (_) {
                          const kTinyCost = 0.0001;

                          final cost = message.cost;
                          if (cost == null) return const SizedBox.shrink();

                          final inferredProviderId = (message.providerId.isNotEmpty)
                              ? message.providerId
                              : (message.pricedAsVseGpt
                                  ? ProviderIds.vsegpt
                                  : ProviderIds.openrouter);

                          final isVse =
                              inferredProviderId == ProviderIds.vsegpt;
                          final isUnknown =
                              inferredProviderId == ProviderIds.unknown;

                          // FREE: не привязываем к списку моделей текущего провайдера,
                          // чтобы после переключения провайдера FREE не “ломался” у старых сообщений.
                          final isFree = !isVse && !isUnknown && cost == 0.0;

                          final String costText;
                          if (isFree) {
                            costText = 'FREE';
                          } else if (cost.abs() < kTinyCost) {
                            costText = isUnknown
                                ? '<0.0001'
                                : (isVse ? '<0.0001₽' : '<0.0001\$');
                          } else {
                            costText = isUnknown
                                ? cost.toStringAsFixed(3)
                                : (isVse
                                    ? '${cost.toStringAsFixed(3)}₽'
                                    : '${cost.toStringAsFixed(3)}\$');
                          }

                          return Text('Стоимость: $costText', style: metaStyle);
                        }),

                      // SETTINGS: показывать источник/модель
                      if (context.select<SettingsProvider, bool>(
                              (s) => s.showModelInfoInChat) &&
                          !message.isUser &&
                          message.modelId != null)
                        Text(
                          'Источник: ${ProviderUtils.providerLabel(message.providerId)} · ${message.modelId}',
                          style: metaStyle,
                        ),

                      actionButtonsRow(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Виджет для ввода сообщений
