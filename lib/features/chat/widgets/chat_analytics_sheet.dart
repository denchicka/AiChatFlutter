import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'analytics/analytics_controls.dart';
import 'analytics/usage_panel.dart';

import '../chat.dart';
import '../../../../analytics/provider_ids.dart';

class ChatAnalyticsSheet extends StatefulWidget {
  const ChatAnalyticsSheet({super.key});

  @override
  State<ChatAnalyticsSheet> createState() => _ChatAnalyticsSheetState();
}

class _ChatAnalyticsSheetState extends State<ChatAnalyticsSheet> {
  ProviderFilter _provider = ProviderFilter.all;
  SortKey _sortKey = SortKey.cost;
  SortDir _sortDir = SortDir.desc;

  void _onSortPressed(SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortDir = _sortDir == SortDir.desc ? SortDir.asc : SortDir.desc;
      } else {
        _sortKey = key;
        _sortDir = SortDir.desc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final unknownTotals = chat.totalsForRange(
          fromInclusive: null,
          toExclusive: null,
          providerFilter: ProviderIds.unknown,
        );

        final showUnknown = unknownTotals.requests > 0 ||
            unknownTotals.tokens > 0 ||
            unknownTotals.cost > 0;

        if (!showUnknown && _provider == ProviderFilter.unknown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _provider = ProviderFilter.all);
          });
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.55,
          maxChildSize: 0.98,
          expand: false,
          builder: (ctx, scrollController) {
            return SafeArea(
              child: Material(
                color: scheme.surface,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  children: [
                    Text(
                      'Статистика',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnalyticsControls(
                      provider: _provider,
                      onProviderChanged: (p) => setState(() => _provider = p),
                      sortKey: _sortKey,
                      sortDir: _sortDir,
                      onSortPressed: _onSortPressed,
                      showUnknown: showUnknown,
                    ),
                    const SizedBox(height: 12),
                    UsagePanel(
                      provider: _provider,
                      sortKey: _sortKey,
                      sortDir: _sortDir,
                      onOpenChat: (modelId, providerId) {
                        // Просим ChatProvider подсветить/проскроллить нужное сообщение.
                        // Все toasts и ошибки он показывает сам.
                        context.read<ChatProvider>().requestScrollToMessage(
                              modelId: modelId,
                              providerId: providerId,
                              preferMaxCost: true,
                              emitToast: true,
                            );

                        Navigator.of(context).pop(); // закрываем аналитику
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
