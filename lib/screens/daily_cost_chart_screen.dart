import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat.dart';
import '../widgets/theme_mode_button.dart';
import '../widgets/settings_icon_button.dart';
import '../widgets/top_toast.dart';
import '../widgets/analytics/analytics_filter_card.dart';
import '../widgets/analytics/analytics_controls.dart';
import '../analytics/provider_ids.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding/onboarding_overlay.dart';

enum _Metric { cost, tokens, requests }

enum _RangePreset { d7, d30, d90, all }

class DailyCostChartScreen extends StatefulWidget {
  const DailyCostChartScreen({super.key});

  @override
  State<DailyCostChartScreen> createState() => _DailyCostChartScreenState();
}

class _DailyCostChartScreenState extends State<DailyCostChartScreen> {
  _Metric _metric = _Metric.cost;
  _Metric _lastNonCostMetric = _Metric.tokens;

  _RangePreset _range = _RangePreset.d30;
  ProviderFilter _provider = ProviderFilter.all;
  bool _providerInited = false;

  final GlobalKey _chartContentKey = GlobalKey();
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      if (onboarding.shouldShowOnboarding('chart')) {
        setState(() {
          _showOnboarding = true;
        });
      }
    });
  }

  void _onOnboardingNext() {
    _completeOnboarding();
  }

  void _onOnboardingSkip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.completeScreen('chart');
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_providerInited) return;

    final chat = context.read<ChatProvider>();
    _provider =
        chat.isVseGpt ? ProviderFilter.vsegpt : ProviderFilter.openrouter;

    _providerInited = true;
  }

  static const _monthsShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек'
  ];
  static const _monthsFull = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря'
  ];

  String _fmtDayShort(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';
  String _fmtDayFull(DateTime d) =>
      '${d.day} ${_monthsFull[d.month - 1]} ${d.year}';

  DateTimeRange? _resolveRange() {
    final now = DateTime.now();
    final endExclusive =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    switch (_range) {
      case _RangePreset.d7:
        return DateTimeRange(
          start: endExclusive.subtract(const Duration(days: 7)),
          end: endExclusive,
        );
      case _RangePreset.d30:
        return DateTimeRange(
          start: endExclusive.subtract(const Duration(days: 30)),
          end: endExclusive,
        );
      case _RangePreset.d90:
        return DateTimeRange(
          start: endExclusive.subtract(const Duration(days: 90)),
          end: endExclusive,
        );
      case _RangePreset.all:
        return null;
    }
  }

  String? _providerKey(ProviderFilter f) {
    return switch (f) {
      ProviderFilter.all => null,
      ProviderFilter.openrouter => ProviderIds.openrouter,
      ProviderFilter.vsegpt => ProviderIds.vsegpt,
      ProviderFilter.unknown => ProviderIds.unknown,
    };
  }

  String _providerLabel(ProviderFilter f) => switch (f) {
        ProviderFilter.all => 'Все',
        ProviderFilter.openrouter => 'OpenRouter',
        ProviderFilter.vsegpt => 'VseGPT',
        ProviderFilter.unknown => 'Unknown',
      };

  String _rangeLabel(_RangePreset r) => switch (r) {
        _RangePreset.d7 => '7Д',
        _RangePreset.d30 => '30Д',
        _RangePreset.d90 => '90Д',
        _RangePreset.all => 'ВСЕ',
      };

  String _metricLabel(_Metric m) => switch (m) {
        _Metric.cost => 'Стоимость',
        _Metric.tokens => 'Токены',
        _Metric.requests => 'Запросы',
      };

  Future<void> _copy(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (!context.mounted) return;
      TopToast.show(context, 'Не удалось скопировать',
          type: TopToastType.error);
      return;
    }

    if (!context.mounted) return;
    TopToast.show(
      context,
      'Скопировано',
      type: TopToastType.success,
      duration: const Duration(seconds: 1),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded,
                size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              'Нет данных для выбранных фильтров',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    ColorScheme scheme,
    List<DailyAggregate> data,
    String currency, {
    required void Function(int index) onBarTap,
  }) {
    double valueOf(DailyAggregate a) => switch (_metric) {
          _Metric.cost => a.cost,
          _Metric.tokens => a.tokens.toDouble(),
          _Metric.requests => a.requests.toDouble(),
        };

    String formatValue(DailyAggregate a) => switch (_metric) {
          _Metric.cost => '${a.cost.toStringAsFixed(6)}$currency',
          _Metric.tokens => '${a.tokens}',
          _Metric.requests => '${a.requests}',
        };

    String compactY(double v) {
      if (_metric == _Metric.cost) {
        if (v.abs() < 0.0001) return '0';
        return v.toStringAsFixed(v < 1 ? 3 : 2);
      }
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
      return v.toStringAsFixed(0);
    }

    final n = data.length;
    
    // Обработка случая, когда данных нет или мало
    if (n == 0) {
      return const Center(
        child: Text('Нет данных для отображения'),
      );
    }
    
    final maxYRaw =
        data.map(valueOf).fold<double>(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxYRaw <= 0) ? 1.0 : (maxYRaw * 1.2);

    // геометрия
    const leftReserved = 72.0; // чуть больше, чтобы подписи слева не упирались
    final barWidth = n <= 3 ? 14.0 : 10.0;
    const groupsSpace = 8.0;

    String bottomLabel(DateTime d) {
      // при малом количестве дней делаем 2 строки (и не слипается)
      if (n <= 14) return '${d.day}\n${_monthsShort[d.month - 1]}';
      return _fmtDayShort(d);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;

        // ширина "по барам" (нужна только если реально надо скроллить)
        final tightWidth = (leftReserved + n * (barWidth + groupsSpace) + 40)
            .clamp(280.0, 20000.0);

        final needScroll = tightWidth > viewWidth;
        final chartWidth = needScroll ? tightWidth : viewWidth;

        // плотность дат на оси X
        final availableForLabels = chartWidth - leftReserved - 24;
        const approxLabelSlot = 48.0;
        final calculatedMaxLabels = (availableForLabels / approxLabelSlot).floor();
        // Исправление: clamp требует min <= max, поэтому проверяем n
        final maxLabels = n >= 2 
            ? calculatedMaxLabels.clamp(2, n)
            : n; // Если n < 2, используем n (1 или 0)
        final labelEvery = maxLabels > 0 ? (n / maxLabels).ceil() : 1;

        final barGroups = List.generate(n, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: valueOf(data[i]),
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                color: scheme.primary,
              ),
            ],
          );
        });

        final chart = SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              // minX: -0.5,   // УДАЛИТЬ
              // maxX: n - 0.5, // УДАЛИТЬ
              maxY: maxY,

              alignment: needScroll
                  ? BarChartAlignment.start
                  : BarChartAlignment.spaceAround,
              groupsSpace: groupsSpace,

              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  strokeWidth: 1,
                ),
              ),

              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: leftReserved,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 10, // чуть правее, чтобы не липло к краю
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          compactY(v),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: n <= 14 ? 42 : 32,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      if (i % labelEvery != 0) return const SizedBox.shrink();

                      final d = data[i].day;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 10,
                        child: Text(
                          bottomLabel(d),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            height: 1.05,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent) {
                    final spot = response?.spot;
                    if (spot == null) return;
                    final idx = spot.touchedBarGroupIndex;
                    if (idx < 0 || idx >= n) return;
                    onBarTap(idx);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: scheme.surfaceContainerHighest,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final i = group.x.toInt();
                    final a = data[i];
                    final d = a.day;
                    final label =
                        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

                    return BarTooltipItem(
                      '$label\n${formatValue(a)}\n'
                      'запросов = ${a.requests} · токенов = ${a.tokens} · ${a.cost.toStringAsFixed(6)}$currency',
                      TextStyle(color: scheme.onSurface, fontSize: 12),
                    );
                  },
                ),
              ),

              barGroups: barGroups,
            ),
          ),
        );

        return needScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: chart)
            : chart;
      },
    );
  }

  void _openDayDetailsSheet(
    BuildContext rootCtx,
    List<DailyAggregate> data,
    int index,
    ProviderFilter provider,
    String currency,
  ) {
    final chat = rootCtx.read<ChatProvider>();
    final scheme = Theme.of(rootCtx).colorScheme;

    final dayAgg = data[index];
    final day = dayAgg.day;

    final byModel = chat
        .usageByModelForDay(day, providerFilter: _providerKey(provider))
        .entries
        .toList()
      ..sort((a, b) => b.value.cost.compareTo(a.value.cost));

    showModalBottomSheet(
      context: rootCtx,
      useRootNavigator: false,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final s = Theme.of(sheetCtx).colorScheme;
        final label = _fmtDayFull(day);

        Widget iconTonal({
          required String tooltip,
          required IconData icon,
          required VoidCallback onPressed,
        }) {
          return IconButton.filledTonal(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
          );
        }

        Widget metricLine(String title, String value) {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$title: $value',
              style: TextStyle(color: s.onSurfaceVariant, fontSize: 12),
            ),
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: s.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    iconTonal(
                      tooltip: 'Перейти к дате',
                      icon: Icons.calendar_today_outlined,
                      onPressed: () {
                        rootCtx.read<ChatProvider>().requestScrollToDay(day);
                        Navigator.of(sheetCtx).pop();
                        rootCtx.go('/chat');
                      },
                    ),
                    const SizedBox(width: 8),
                    iconTonal(
                      tooltip: 'Копировать',
                      icon: Icons.copy,
                      onPressed: () {
                        final text = 'Дата: $label\n'
                                'Запросов: ${dayAgg.requests}\n'
                                'Токенов: ${dayAgg.tokens}\n'
                                'Стоимость: ${dayAgg.cost.toStringAsFixed(6)}$currency\n\n'
                                'Модели:\n${byModel.map((e) {
                              final u = e.value;
                              return '- ${e.key}: запросов = ${u.requests}, токенов = ${u.tokens}, стоимость = ${u.cost.toStringAsFixed(6)}$currency';
                            }).join('\n')}';

                        _copy(sheetCtx, text);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                metricLine('Запросов', '${dayAgg.requests}'),
                metricLine('Токенов', '${dayAgg.tokens}'),
                metricLine(
                    'Стоимость', '${dayAgg.cost.toStringAsFixed(6)}$currency'),
                const SizedBox(height: 14),
                Text(
                  'Модели за день',
                  style: TextStyle(
                    color: s.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (byModel.isEmpty)
                  Text(
                    'Нет детализации',
                    style: TextStyle(
                      color: s.onSurfaceVariant.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  )
                else
                  ...byModel.map((e) {
                    final u = e.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: s.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: s.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: s.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'запросов = ${u.requests} · токенов = ${u.tokens} · ${u.cost.toStringAsFixed(6)}$currency',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: s.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Перейти к сообщению',
                            icon:
                                const Icon(Icons.chat_bubble_outline, size: 18),
                            onPressed: () {
                              final ok = rootCtx
                                  .read<ChatProvider>()
                                  .requestScrollToMessage(
                                    day: day,
                                    modelId: e.key,
                                    providerId: _providerKey(provider),
                                    preferMaxCost: true,
                                    emitToast: false,
                                  );

                              Navigator.of(sheetCtx).pop();

                              if (!ok) {
                                TopToast.show(rootCtx, 'Сообщение не найдено',
                                    type: TopToastType.info);
                                return;
                              }

                              rootCtx.go('/chat');
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Копировать',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              _copy(
                                sheetCtx,
                                'Дата: $label\nМодель: ${e.key}\n'
                                'запросов = ${u.requests}\n'
                                'токенов = ${u.tokens}\n'
                                'стоимость = ${u.cost.toStringAsFixed(6)}$currency',
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            toolbarHeight: 48,
            title: const Text('Расходы по дням', style: TextStyle(fontSize: 14)),
            leading: IconButton(
              tooltip: 'На главную',
              icon: Icon(Icons.home, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () => context.go('/home'),
            ),
            actions: const [
              ThemeModeButton(),
              SettingsIconButton(),
              SizedBox(width: 8),
            ],
          ),
          body: Container(
            key: _chartContentKey,
            child: Consumer<ChatProvider>(
              builder: (context, chat, _) {
          final range = _resolveRange();

          final data = chat.dailyAggregatesForRange(
            fromInclusive: range?.start,
            toExclusive: range?.end,
            providerFilter: _providerKey(_provider),
          );

          final hasData = data.isNotEmpty;

          final currency = switch (_provider) {
            ProviderFilter.vsegpt => '₽',
            ProviderFilter.openrouter => '\$',
            _ => '',
          };

          void onProviderPicked(ProviderFilter p) {
            final wasCost = _metric == _Metric.cost;

            setState(() {
              _provider = p;
              if (_provider == ProviderFilter.all && wasCost) {
                _metric = _lastNonCostMetric;
              }
            });

            if (p == ProviderFilter.all && wasCost) {
              TopToast.show(
                context,
                'Стоимость доступна только для конкретного провайдера',
                type: TopToastType.info,
                duration: const Duration(seconds: 2),
              );
            }
          }

          void onMetricPicked(_Metric m) {
            final needSwitchProvider =
                (m == _Metric.cost && _provider == ProviderFilter.all);
            final fallbackProvider = chat.isVseGpt
                ? ProviderFilter.vsegpt
                : ProviderFilter.openrouter;

            setState(() {
              _metric = m;
              if (m != _Metric.cost) _lastNonCostMetric = m;
              if (needSwitchProvider) _provider = fallbackProvider;
            });

            if (needSwitchProvider) {
              TopToast.show(
                context,
                'Для стоимости выбран конкретный провайдер',
                type: TopToastType.info,
                duration: const Duration(seconds: 2),
              );
            }
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                AnalyticsFilterCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnalyticsChipGroup<_RangePreset>(
                        title: 'Дни',
                        values: _RangePreset.values,
                        value: _range,
                        onChanged: (v) => setState(() => _range = v),
                        labelBuilder: _rangeLabel,
                      ),
                      const SizedBox(height: 10),
                      AnalyticsChipGroup<ProviderFilter>(
                        title: 'Провайдер',
                        values: const [
                          ProviderFilter.all,
                          ProviderFilter.openrouter,
                          ProviderFilter.vsegpt,
                        ],
                        value: _provider,
                        onChanged: onProviderPicked,
                        labelBuilder: _providerLabel,
                      ),
                      const SizedBox(height: 10),
                      AnalyticsChipGroup<_Metric>(
                        title: 'Показатель',
                        values: _Metric.values,
                        value: _metric,
                        onChanged: onMetricPicked,
                        labelBuilder: _metricLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _sectionCard(
                    context,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
                      child: !hasData
                          ? _emptyState(context)
                          : _buildChart(
                              context,
                              scheme,
                              data,
                              currency,
                              onBarTap: (i) => _openDayDetailsSheet(
                                  context, data, i, _provider, currency),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
              },
            ),
          ),
        ),

        // Onboarding overlay
        if (_showOnboarding)
          OnboardingOverlay(
            targetKey: _chartContentKey,
            title: 'График расходов',
            description:
                'Визуализация расходов на использование AI по дням. Выберите период, провайдера и показатель (стоимость, токены или запросы) для анализа. Помогает отслеживать бюджет и оптимизировать использование.',
            position: TooltipPosition.top,
            currentStep: 1,
            totalSteps: 1,
            onNext: _onOnboardingNext,
            onSkip: _onOnboardingSkip,
          ),
      ],
    );
  }
}
