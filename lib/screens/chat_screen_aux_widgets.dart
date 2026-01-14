part of 'chat_screen.dart';

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundary: $error');
          debugPrint('Stack trace: $stackTrace');
          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red,
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }
      },
    );
  }
}

void _showAnalyticsSheet(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const ChatAnalyticsSheet(),
  );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionText;
  final VoidCallback? onAction;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.body,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: s.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: s.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: s.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (actionText != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(actionText!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showOpenRouterBalanceInfo(BuildContext context, ChatProvider chat) {
  final scheme = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final s = Theme.of(ctx).colorScheme;

      final topUpUrl = chat.topUpUrl;
      Future<void> openSource() async {
        final uri = Uri.tryParse(topUpUrl ?? '');
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Баланс OpenRouter',
                style: TextStyle(
                  color: s.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _InfoBox(
                icon: Icons.public,
                title: 'Источник',
                body:
                    'Информация в этом окне взята с сайта OpenRouter (страница биллинга/пополнения) '
                    'и может со временем меняться.',
                actionText: (topUpUrl == null) ? null : 'Открыть источник',
                onAction: (topUpUrl == null) ? null : openSource,
              ),
              const SizedBox(height: 12),
              Text(
                'Текущий баланс: ${chat.balance}',
                style: TextStyle(
                  color: s.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Почему на сайте может быть небольшой минус',
                style: TextStyle(
                  color: s.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Есть небольшой лимит использования (обычно менее \$1), прежде чем потребуется пополнение.\n'
                '• Платежи обрабатываются через Stripe — данные карты приложение не хранит.\n'
                '• Итоговая стоимость зависит от выбранной модели и комиссий при покупке кредита.',
                style: TextStyle(
                  color: s.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class BalanceChip extends StatelessWidget {
  const BalanceChip({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final scheme = Theme.of(context).colorScheme;

    final url = chat.topUpUrl;

    // OpenRouter = не VseGPT (вы уже используете isVseGpt в других местах)
    final isOpenRouter = !chat.isVseGpt;

    // баланс отрицательный, но не "большой минус"
    final showAllowanceHint =
        isOpenRouter && chat.balanceValue < 0 && chat.balanceValue > -1.0;

    // БАЗОВЫЕ паддинги чипа (как было)
    const baseHPad = 10.0;
    const vPad = 6.0;

    // Если есть "i" — резервируем место справа внутри чипа, но только тогда
    const infoSlotW = 26.0; // место под кнопку + небольшой зазор
    final rightPad = baseHPad + (showAllowanceHint ? infoSlotW : 0.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Сам чип баланса (тап по нему — пополнение)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: url == null
                  ? null
                  : () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
              child: Padding(
                padding: EdgeInsets.fromLTRB(baseHPad, vPad, rightPad, vPad),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(chat.balance),
                  ],
                ),
              ),
            ),
          ),

          // Кнопка "i" — ВНУТРИ чипа, чтобы AppBar не раздувался по ширине
          if (showAllowanceHint)
            Positioned(
              right: 4,
              child: _TinyIconButton(
                tooltip: 'Почему баланс может быть отрицательным?',
                icon: Icons.info_outline,
                color: scheme.onSurfaceVariant,
                onPressed: () => _showOpenRouterBalanceInfo(context, chat),
              ),
            ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TinyIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkResponse(
          onTap: onPressed,
          radius: 16,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

