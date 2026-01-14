import 'package:flutter/material.dart';

enum ProviderFilter { all, openrouter, vsegpt, unknown }

enum SortKey { cost, tokens, requests }

enum SortDir { asc, desc }

class AnalyticsChipGroup<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelBuilder;
  final bool scrollable;

  const AnalyticsChipGroup({
    super.key,
    required this.title,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.labelBuilder,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final segmented = SegmentedButton<T>(
      showSelectedIcon: false,
      segments: values
          .map((v) => ButtonSegment<T>(
                value: v,
                label: Text(
                  labelBuilder(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ))
          .toList(),
      selected: <T>{value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (scrollable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: segmented,
            )
          else
            SizedBox(width: double.infinity, child: segmented),
        ],
      ),
    );
  }
}

class AnalyticsControls extends StatelessWidget {
  final ProviderFilter provider;
  final ValueChanged<ProviderFilter> onProviderChanged;

  final SortKey sortKey;
  final SortDir sortDir;
  final ValueChanged<SortKey> onSortPressed;

  final bool showUnknown;

  const AnalyticsControls({
    super.key,
    required this.provider,
    required this.onProviderChanged,
    required this.sortKey,
    required this.sortDir,
    required this.onSortPressed,
    this.showUnknown = false,
  });

  String _providerLabel(ProviderFilter f) => switch (f) {
        ProviderFilter.all => 'Все',
        ProviderFilter.openrouter => 'OpenRouter',
        ProviderFilter.vsegpt => 'VseGPT',
        ProviderFilter.unknown => 'Unknown',
      };

  String _sortLabel(SortKey k) => switch (k) {
        SortKey.cost => 'Стоимость',
        SortKey.tokens => 'Токены',
        SortKey.requests => 'Ответы',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final providerValues = <ProviderFilter>[
      ProviderFilter.all,
      ProviderFilter.openrouter,
      ProviderFilter.vsegpt,
      if (showUnknown) ProviderFilter.unknown,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnalyticsChipGroup<ProviderFilter>(
          title: 'Провайдер',
          values: providerValues,
          value: provider,
          onChanged: onProviderChanged,
          labelBuilder: _providerLabel,
          scrollable: false,
        ),
        Text(
          'Сортировка',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<SortKey>(
                showSelectedIcon: false,
                segments: SortKey.values
                    .map((k) => ButtonSegment(
                          value: k,
                          label: Text(_sortLabel(k)),
                          icon: Icon(
                            k == SortKey.cost
                                ? Icons.attach_money_rounded
                                : k == SortKey.tokens
                                    ? Icons.data_usage_rounded
                                    : Icons.chat_bubble_outline,
                            size: 18,
                          ),
                        ))
                    .toList(),
                selected: <SortKey>{sortKey},
                onSelectionChanged: (s) => onSortPressed(s.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip:
                  sortDir == SortDir.asc ? 'По возрастанию' : 'По убыванию',
              onPressed: () => onSortPressed(sortKey),
              icon: Icon(
                sortDir == SortDir.asc
                    ? Icons.south_rounded
                    : Icons.north_rounded,
                size: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
