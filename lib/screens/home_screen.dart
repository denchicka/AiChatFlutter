import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/settings_icon_button.dart';
import '../widgets/top_toast.dart';
import '../widgets/onboarding/onboarding_overlay.dart';

import '../settings/settings_provider.dart';
import '../settings/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _checkedUpdatesThisSession = false;

  SettingsProvider? _settingsProvider;
  OnboardingProvider? _onboardingProvider;

  // Ключи для onboarding
  final GlobalKey _statusCardKey = GlobalKey();
  final GlobalKey _chatTileKey = GlobalKey();
  final GlobalKey _providerTileKey = GlobalKey();
  final GlobalKey _statsTileKey = GlobalKey();
  final GlobalKey _chartTileKey = GlobalKey();
  final GlobalKey _settingsTileKey = GlobalKey();

  int _onboardingStep = 0;
  bool _showOnboarding = false;
  bool _isRepeatingOnboarding = false; // Флаг повторного обучения

  final List<_OnboardingStep> _onboardingSteps = [];

  @override
  void initState() {
    super.initState();

    _initializeOnboardingSteps();

    // Подвязываемся после первого кадра, чтобы:
    // 1) точно был ScaffoldMessenger
    // 2) Provider уже был в дереве
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final sp = context.read<SettingsProvider>();
      _settingsProvider = sp;
      sp.addListener(_onSettingsChangedOrLoaded);

      // попробовать сразу (если settings уже загружены)
      _onSettingsChangedOrLoaded();

      // Проверяем onboarding (только после загрузки состояния)
      final onboarding = context.read<OnboardingProvider>();
      _onboardingProvider = onboarding;
      if (onboarding.loaded && onboarding.shouldShowOnboarding('home')) {
        // Определяем, является ли это повторным обучением
        // Если welcome screen был пройден, значит это повторное обучение
        final isRepeating = onboarding.welcomeCompleted;
        setState(() {
          _onboardingStep = 0; // Сбрасываем шаг при повторном обучении
          _showOnboarding = true;
          _isRepeatingOnboarding = isRepeating;
        });
      }
      
      // Слушаем изменения onboarding для сброса шага при повторном обучении
      onboarding.addListener(_onOnboardingChanged);
    });
  }
  
  void _onOnboardingChanged() {
    if (!mounted) return;
    final onboarding = context.read<OnboardingProvider>();
    if (onboarding.loaded && onboarding.shouldShowOnboarding('home')) {
      // Определяем, является ли это повторным обучением
      final isRepeating = onboarding.welcomeCompleted;
      if (!_showOnboarding || _onboardingStep != 0) {
        setState(() {
          _onboardingStep = 0; // Сбрасываем шаг при повторном обучении
          _showOnboarding = true;
          _isRepeatingOnboarding = isRepeating;
        });
      }
    } else if (_showOnboarding) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  void _initializeOnboardingSteps() {
    _onboardingSteps.addAll([
      _OnboardingStep(
        key: _statusCardKey,
        title: 'Статус системы',
        description:
            'Здесь отображается текущий статус вашего подключения к провайдеру AI и состояние авторизации.',
        position: TooltipPosition.bottom,
      ),
      _OnboardingStep(
        key: _chatTileKey,
        title: 'Чат с AI',
        description:
            'Основной экран для общения с искусственным интеллектом. Здесь вы можете задавать вопросы и получать ответы.',
        position: TooltipPosition.bottom,
      ),
      _OnboardingStep(
        key: _providerTileKey,
        title: 'Настройка провайдера',
        description:
            'Настройте API ключ для OpenRouter или VseGPT. Это необходимо для работы с AI моделями.',
        position: TooltipPosition.bottom,
      ),
      _OnboardingStep(
        key: _statsTileKey,
        title: 'Статистика токенов',
        description:
            'Просматривайте детальную статистику использования токенов по каждой модели.',
        position: TooltipPosition.bottom,
      ),
      _OnboardingStep(
        key: _chartTileKey,
        title: 'График расходов',
        description:
            'Визуализация расходов на использование AI по дням. Помогает отслеживать бюджет.',
        position: TooltipPosition.bottom,
      ),
      _OnboardingStep(
        key: _settingsTileKey,
        title: 'Настройки',
        description:
            'Настройте уведомления, тему оформления, обновления и другие параметры приложения.',
        position: TooltipPosition.bottom,
      ),
    ]);
  }

  void _onOnboardingNext() {
    if (_onboardingStep < _onboardingSteps.length - 1) {
      setState(() {
        _onboardingStep++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _onOnboardingSkip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.completeScreen('home');
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChangedOrLoaded);
    _onboardingProvider?.removeListener(_onOnboardingChanged);
    super.dispose();
  }

  Future<void> _onSettingsChangedOrLoaded() async {
    if (!mounted) return;
    if (_checkedUpdatesThisSession) return;

    final sp = _settingsProvider;
    if (sp == null) return;

    // Если у тебя в SettingsProvider есть флаг loaded — используем.
    // Если нет — тоже ок: просто не будем проверять, пока repo/owner не заполнены.
    final loaded =
        (sp as dynamic).loaded == null ? true : (sp as dynamic).loaded as bool;
    if (!loaded) return;

    final s = sp.s;

    if (!s.checkUpdatesOnStartup) return;
    if (s.githubOwner.trim().isEmpty || s.githubRepo.trim().isEmpty) return;

    // С этого момента считаем, что попытка проверки уже была (даже если упадёт по сети),
    // чтобы не спамить при каждом заходе на Home.
    _checkedUpdatesThisSession = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final upd = await UpdateService.instance.checkGithubLatest(
        owner: s.githubOwner.trim(),
        repo: s.githubRepo.trim(),
        currentVersion: currentVersion,
      );

      if (!mounted) return;

      if (!upd.hasUpdate) {
        // На старте обычно лучше НЕ показывать "обновлений нет", чтобы не шуметь.
        return;
      }

      TopToast.show(
        context,
        'Доступно обновление: ${upd.latest} (у вас ${upd.current})',
        type: TopToastType.info,
        duration: const Duration(seconds: 10),
        actionLabel: 'Открыть',
        onAction: () async {
          // Сохраняем context до async операций для безопасного использования
          final ctx = context;
          final uri = Uri.tryParse(upd.htmlUrl);
          if (uri == null) {
            if (!ctx.mounted) return;
            TopToast.show(
              ctx,
              'Некорректная ссылка обновления',
              type: TopToastType.error,
              duration: const Duration(seconds: 2),
            );
            return;
          }
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (!ctx.mounted) return;
            TopToast.show(
              ctx,
              'Не удалось открыть ссылку: $e',
              type: TopToastType.error,
              duration: const Duration(seconds: 3),
            );
          }
        },
      );
    } catch (e, st) {
      debugPrint('Update check failed: $e');
      debugPrint('Stack: $st');

      if (!mounted) return;

      TopToast.show(
        context,
        'Не удалось проверить обновления: $e',
        type: TopToastType.info,
        duration: const Duration(seconds: 3),
      );
    }
  }

  String _enumName(Object? v) => v == null ? '—' : v.toString().split('.').last;

  String _stageLabel(Object? v) {
    final name = _enumName(v);
    switch (name) {
      case 'needsApiKey':
        return 'нужен API-ключ';
      case 'needsPin':
        return 'нужен PIN-код';
      case 'authenticated':
        return 'авторизован';
      case 'invalidApiKey':
        return 'ключ недействителен';
      case 'locked':
        return 'заблокирован';
      case 'unauthenticated':
        return 'не авторизован';
      case '—':
        return '—';
      default:
        return name;
    }
  }

  String _providerLabel(Object? v) {
    final name = _enumName(v);
    switch (name) {
      case 'openRouter':
        return 'OpenRouter';
      case 'vseGpt':
        return 'VseGPT';
      case '—':
        return '—';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    final unlocked = auth.decryptedApiKeyForSession != null;
    final isFirstLaunch = !onboarding.welcomeCompleted;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('AIChatFlutter'),
            actions: [
              SettingsIconButton(),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _StatusCard(
                        key: _statusCardKey,
                        provider: _providerLabel(auth.storedProviderType),
                        stage: _stageLabel(auth.authenticationStage),
                        unlocked: unlocked,
                      ),
                      const SizedBox(height: 12),
                      _NavTile(
                        key: _chatTileKey,
                        title: 'Чат',
                        subtitle:
                            'Перейти в чат (если сессия настроена/разблокирована)',
                        icon: Icons.chat,
                        onTap: () => context.push('/chat'),
                      ),
                      _NavTile(
                        key: _providerTileKey,
                        title: 'Провайдер',
                        subtitle: 'Настроить OpenRouter / VseGPT и ключ',
                        icon: Icons.settings,
                        onTap: () => context.push('/provider'),
                      ),
                      _NavTile(
                        key: _statsTileKey,
                        title: 'Статистика токенов',
                        subtitle: 'Использование токенов по моделям',
                        icon: Icons.analytics,
                        onTap: () => context.push('/stats'),
                      ),
                      _NavTile(
                        key: _chartTileKey,
                        title: 'График расходов',
                        subtitle: 'Расходы по дням',
                        icon: Icons.show_chart,
                        onTap: () => context.push('/chart'),
                      ),
                      _NavTile(
                        key: _settingsTileKey,
                        title: 'Настройки',
                        subtitle: 'Уведомления, тема, обновления и прочее',
                        icon: Icons.tune,
                        onTap: () => context.push('/settings'), // было: go
                      ),
                    ],
                  ),
                ),
                // Показываем надпись только при первом запуске
                if (isFirstLaunch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Center(
                      child: Text(
                        'Стартовая страница не показывает ключи и не логирует секреты.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Onboarding overlay
        if (_showOnboarding && _onboardingStep < _onboardingSteps.length)
          OnboardingOverlay(
            key: ValueKey('onboarding_$_onboardingStep'),
            targetKey: _onboardingSteps[_onboardingStep].key,
            title: _onboardingSteps[_onboardingStep].title,
            description: _onboardingSteps[_onboardingStep].description,
            position: _onboardingSteps[_onboardingStep].position,
            currentStep: _onboardingStep + 1,
            totalSteps: _onboardingSteps.length,
            onNext: _onOnboardingNext,
            onSkip: _onOnboardingSkip,
            showSkip: !_isRepeatingOnboarding, // Скрываем кнопку "Пропустить" при повторном обучении
          ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: radius),
        hoverColor: scheme.primary.withValues(alpha: 0.06),
        splashColor: Colors.transparent,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

class _OnboardingStep {
  final GlobalKey key;
  final String title;
  final String description;
  final TooltipPosition position;

  _OnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.position,
  });
}

class _StatusCard extends StatelessWidget {
  final String provider;
  final String stage;
  final bool unlocked;

  const _StatusCard({
    super.key,
    required this.provider,
    required this.stage,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // лёгкий “успешный” зелёный (в тон Material, но не кислотный)
    const ok = Color(0xFF34C759);
    final okBg = Color.alphaBlend(ok.withValues(alpha: 0.18), scheme.surface);

    final warnBg = Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.16),
      scheme.surface,
    );

    final pillBg = unlocked ? okBg : warnBg;
    final pillFg = scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                'Статус',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _StatusPill(
                bg: pillBg,
                fg: pillFg,
                icon: unlocked
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                text: unlocked ? 'Готово' : 'Нужно настроить',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusMetric(
                  icon: Icons.hub_outlined,
                  value: provider,
                  label: 'Провайдер',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusMetric(
                  icon: Icons.vpn_key_outlined,
                  value: stage,
                  label: 'Ключ',
                  iconSize: 22, // Больший размер иконки для API-ключа
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusMetric(
                  icon: unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  value: unlocked ? 'Разблокирован' : 'Закрыт',
                  label: 'Сессия',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final double iconSize;

  const _StatusMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.iconSize = 18, // Размер по умолчанию
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.80),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String text;

  const _StatusPill({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
