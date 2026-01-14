import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/chat/chat.dart';
import '../../analytics/provider_ids.dart';
import 'analytics_controls.dart';
import '../../widgets/top_toast.dart';

class UsagePanel extends StatelessWidget {
  final ProviderFilter provider;
  final SortKey sortKey;
  final SortDir sortDir;

  final DateTime? fromInclusive;
  final DateTime? toExclusive;

  /// callback: открыть чат и перейти к сообщению по модели/провайдеру в выбранном диапазоне
  final void Function(String modelId, String? providerId)? onOpenChat;

  const UsagePanel({
    super.key,
    required this.provider,
    required this.sortKey,
    required this.sortDir,
    this.fromInclusive,
    this.toExclusive,
    this.onOpenChat,
  });

  String? _providerKey(ProviderFilter f) {
    return switch (f) {
      ProviderFilter.all => null,
      ProviderFilter.openrouter => ProviderIds.openrouter,
      ProviderFilter.vsegpt => ProviderIds.vsegpt,
      ProviderFilter.unknown => ProviderIds.unknown,
    };
  }

  String _providerTitle(ProviderFilter f) => switch (f) {
        ProviderFilter.all => 'Все',
        ProviderFilter.openrouter => 'OpenRouter',
        ProviderFilter.vsegpt => 'VseGPT',
        ProviderFilter.unknown => 'Unknown',
      };

  int _cmp(ModelUsage a, ModelUsage b) {
    num va;
    num vb;
    switch (sortKey) {
      case SortKey.cost:
        va = a.cost;
        vb = b.cost;
        break;
      case SortKey.tokens:
        va = a.tokens;
        vb = b.tokens;
        break;
      case SortKey.requests:
        va = a.requests;
        vb = b.requests;
        break;
    }
    final raw = va.compareTo(vb);
    return sortDir == SortDir.asc ? raw : -raw;
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    TopToast.show(
      context,
      'Скопировано',
      type: TopToastType.success,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<ChatProvider>(
      builder: (context, chat, _) {

        final providersToShow = provider == ProviderFilter.all
            ? <ProviderFilter>[
                ProviderFilter.openrouter,
                ProviderFilter.vsegpt,
                ProviderFilter.unknown,
              ]
            : <ProviderFilter>[provider];

        bool anyData = false;

        final sections = providersToShow.map((pf) {
          final pk = _providerKey(pf);

          final totals = chat.totalsForRange(
            fromInclusive: fromInclusive,
            toExclusive: toExclusive,
            providerFilter: pk,
          );

          final byModel = chat.usageByModelForRange(
            fromInclusive: fromInclusive,
            toExclusive: toExclusive,
            providerFilter: pk,
          );

          final items = byModel.entries.toList()
            ..sort((a, b) => _cmp(a.value, b.value));

          if (items.isEmpty) return const SizedBox.shrink();
          anyData = true;

          final providerTitle = _providerTitle(pf);
          final totalsCostText = CostFormatter.formatCostForProvider(totals.cost, pf: pf);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider == ProviderFilter.all)
                  _ProviderSectionHeader(title: providerTitle),
                _KpiCard(
                  totals: totals,
                  costText: totalsCostText,
                  onCopy: () {
                    final text = 'Провайдер: $providerTitle\n'
                        'Ответов ИИ: ${totals.requests}\n'
                        'Токенов: ${totals.tokens}\n'
                        'Стоимость: $totalsCostText';
                    _copy(context, text);
                  },
                ),
                const SizedBox(height: 10),
                ...items.map((e) {
                  final modelId = e.key;
                  final u = e.value;

                  final avgTokens =
                      u.requests > 0 ? (u.tokens / u.requests) : 0.0;
                  final avgCost = u.requests > 0 ? (u.cost / u.requests) : 0.0;
                  final costText = CostFormatter.formatCostForProvider(u.cost, pf: pf);
                  final avgCostText = CostFormatter.formatCostForProvider(avgCost, pf: pf);

                  return _ModelUsageCard(
                    modelId: modelId,
                    usage: u,
                    costText: costText,
                    avgTokens: avgTokens,
                    avgCostText: avgCostText,
                    onCopy: () {
                      final text = 'Провайдер: $providerTitle\n'
                          'Модель: $modelId\n'
                          'Ответов: ${u.requests}\n'
                          'Токенов: ${u.tokens}\n'
                          'Стоимость: $costText\n'
                          'Среднее токенов/запрос: ${avgTokens.toStringAsFixed(1)}\n'
                          'Средняя стоимость/запрос: $avgCostText';
                      _copy(context, text);
                    },
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        useRootNavigator: false,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: scheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (_) => _ModelDetailSheet(
                          modelId: modelId,
                          usage: u,
                          costText: costText,
                          avgTokens: avgTokens,
                          avgCostText: avgCostText,
                          onCopy: () {
                            final text = 'Провайдер: $providerTitle\n'
                                'Модель: $modelId\n'
                                'Ответов: ${u.requests}\n'
                                'Токенов: ${u.tokens}\n'
                                'Стоимость: $costText\n'
                                'Среднее токенов/запрос: ${avgTokens.toStringAsFixed(1)}\n'
                                'Средняя стоимость/запрос: $avgCostText';
                            _copy(context, text);
                          },
                          onOpenChat: (onOpenChat == null)
                              ? null
                              : () => onOpenChat!(modelId, pk),
                        ),
                      );
                    },
                    onOpenMessage: (onOpenChat == null)
                        ? null
                        : () => onOpenChat!(modelId, pk),
                  );
                }),
              ],
            ),
          );
        }).toList();

        if (!anyData) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Нет данных',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Важно: отступы внутри внешней обводки (StatsScreen оборачивает UsagePanel в card)
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: sections),
        );
      },
    );
  }
}

class _ProviderSectionHeader extends StatelessWidget {
  final String title;
  const _ProviderSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 12 : 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String costText;
  final ModelUsage totals;
  final VoidCallback onCopy;

  const _KpiCard({
    required this.costText,
    required this.totals,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Итого',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Копировать',
                onPressed: onCopy,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.chat_bubble_outline,
                text: 'Ответов ИИ: ${totals.requests}',
              ),
              _StatChip(
                icon: Icons.data_usage_rounded,
                text: 'Токенов: ${totals.tokens}',
              ),
              _StatChip(
                icon: Icons.attach_money_rounded,
                text: 'Стоимость: $costText',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelUsageCard extends StatelessWidget {
  final String modelId;
  final ModelUsage usage;

  final String costText;
  final double avgTokens;
  final String avgCostText;

  final VoidCallback onCopy;
  final VoidCallback onTap;
  final VoidCallback? onOpenMessage;

  const _ModelUsageCard({
    required this.modelId,
    required this.usage,
    required this.costText,
    required this.avgTokens,
    required this.avgCostText,
    required this.onCopy,
    required this.onTap,
    this.onOpenMessage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          modelId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onOpenMessage != null)
                        IconButton.filledTonal(
                          tooltip: 'Перейти к сообщению',
                          onPressed: onOpenMessage,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.near_me_outlined, size: 18),
                        ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Копировать',
                        onPressed: onCopy,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.copy, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                          icon: Icons.chat_bubble_outline,
                          text: 'Ответов: ${usage.requests}'),
                      _StatChip(
                          icon: Icons.data_usage_rounded,
                          text: 'Токенов: ${usage.tokens}'),
                      _StatChip(
                          icon: Icons.attach_money_rounded,
                          text: 'Стоимость: $costText'),
                      _StatChip(
                          icon: Icons.analytics_outlined,
                          text:
                              'Средн. токенов: ${avgTokens.toStringAsFixed(1)}'),
                      _StatChip(
                          icon: Icons.trending_up_rounded,
                          text: 'Средн. стоимость: $avgCostText'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelDetailSheet extends StatelessWidget {
  final String modelId;
  final ModelUsage usage;

  final String costText;
  final double avgTokens;
  final String avgCostText;

  final VoidCallback onCopy;
  final VoidCallback? onOpenChat;

  const _ModelDetailSheet({
    required this.modelId,
    required this.usage,
    required this.costText,
    required this.avgTokens,
    required this.avgCostText,
    required this.onCopy,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      modelId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onOpenChat != null) ...[
                    IconButton.filledTonal(
                      tooltip: 'Перейти к сообщению',
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenChat!.call();
                      },
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton.filledTonal(
                    tooltip: 'Копировать',
                    onPressed: onCopy,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                      icon: Icons.chat_bubble_outline,
                      text: 'Ответов: ${usage.requests}'),
                  _StatChip(
                      icon: Icons.data_usage_rounded,
                      text: 'Токенов: ${usage.tokens}'),
                  _StatChip(
                      icon: Icons.attach_money_rounded,
                      text: 'Стоимость: $costText'),
                  _StatChip(
                      icon: Icons.analytics_outlined,
                      text: 'Средн. токенов: ${avgTokens.toStringAsFixed(1)}'),
                  _StatChip(
                      icon: Icons.trending_up_rounded,
                      text: 'Средн. стоимость: $avgCostText'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
