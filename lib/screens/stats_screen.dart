import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat.dart';
import '../widgets/top_toast.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding/onboarding_overlay.dart';

import '../widgets/settings_icon_button.dart';
import '../widgets/analytics/analytics_controls.dart';
import '../widgets/analytics/usage_panel.dart';
import '../widgets/analytics/analytics_filter_card.dart';

enum _RangePreset { d7, d30, d90, all }

String _fmt2(int v) => v.toString().padLeft(2, '0');

String _fmtRange(DateTimeRange r) {
  final endInc = r.end.subtract(const Duration(days: 1));
  return '${_fmt2(r.start.day)}.${_fmt2(r.start.month)}.${r.start.year}'
      ' — ${_fmt2(endInc.day)}.${_fmt2(endInc.month)}.${endInc.year}';
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _RangePreset _range = _RangePreset.d30;

  ProviderFilter _provider = ProviderFilter.all;
  SortKey _sortKey = SortKey.cost;
  SortDir _sortDir = SortDir.desc;

  final GlobalKey _statsContentKey = GlobalKey();
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      if (onboarding.shouldShowOnboarding('stats')) {
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
    await onboarding.completeScreen('stats');
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

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

  String _rangeLabel(_RangePreset r) => switch (r) {
        _RangePreset.d7 => '7Д',
        _RangePreset.d30 => '30Д',
        _RangePreset.d90 => '90Д',
        _RangePreset.all => 'ВСЕ',
      };

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

  @override
  Widget build(BuildContext context) {
    final range = _resolveRange();

    return WillPopScope(
      onWillPop: () async {
        if (!context.mounted) return false;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return false;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              toolbarHeight: 48,
              title: const Text('Статистика', style: TextStyle(fontSize: 14)),
              actions: const [
                SettingsIconButton(),
                SizedBox(width: 8),
              ],
            ),
            body: ListView(
            key: _statsContentKey,
            padding: const EdgeInsets.all(12),
            children: [
          AnalyticsFilterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnalyticsChipGroup<_RangePreset>(
                  title: 'Период',
                  values: _RangePreset.values,
                  value: _range,
                  onChanged: (v) => setState(() => _range = v),
                  labelBuilder: _rangeLabel,
                  scrollable: false,
                ),
                if (range != null) AnalyticsInlineHint(_fmtRange(range)),
                const SizedBox(height: 12),
                AnalyticsControls(
                  provider: _provider,
                  onProviderChanged: (p) => setState(() => _provider = p),
                  sortKey: _sortKey,
                  sortDir: _sortDir,
                  onSortPressed: _onSortPressed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            child: UsagePanel(
              provider: _provider,
              sortKey: _sortKey,
              sortDir: _sortDir,
              fromInclusive: range?.start,
              toExclusive: range?.end,
              onOpenChat: (modelId, providerId) {
                final chat = context.read<ChatProvider>();

                final ok = chat.requestScrollToMessage(
                  fromInclusive: range?.start,
                  toExclusive: range?.end,
                  modelId: modelId,
                  providerId: providerId,
                  preferMaxCost: true,
                  emitToast: false,
                );

                if (!ok) {
                  TopToast.show(context, 'Сообщение не найдено',
                      type: TopToastType.info);
                  return;
                }

                context.go('/chat');
              },
            ),
          ),
            ],
          ),
        ),

        // Onboarding overlay
        if (_showOnboarding)
          OnboardingOverlay(
            targetKey: _statsContentKey,
            title: 'Статистика токенов',
            description:
                'Здесь вы можете просмотреть детальную статистику использования токенов по каждой модели. Используйте фильтры для выбора периода и провайдера, а также сортировку для удобного просмотра данных.',
            position: TooltipPosition.top,
            currentStep: 1,
            totalSteps: 1,
            onNext: _onOnboardingNext,
            onSkip: _onOnboardingSkip,
          ),
        ],
      ),
    );
  }
}
