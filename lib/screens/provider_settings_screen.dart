import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../widgets/theme_mode_button.dart';
import '../widgets/settings_icon_button.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding/onboarding_overlay.dart';

import '../providers/auth_provider.dart';
import 'auth/api_key_entry_screen.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final GlobalKey _providerContentKey = GlobalKey();
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      if (onboarding.shouldShowOnboarding('provider')) {
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
    await onboarding.completeScreen('provider');
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  String _providerLabel(Object? v) {
    final name = v == null ? '—' : v.toString().split('.').last;
    switch (name) {
      case 'openRouter':
        return 'OpenRouter';
      case 'vseGpt':
        return 'VseGPT';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = _providerLabel(auth.storedProviderType);

    Widget stageBody() {
      if (auth.authenticationStage == AuthenticationStage.needsApiKey ||
          auth.authenticationStage == AuthenticationStage.unknown) {
        return const ApiKeyEntryScreen();
      }

      if (auth.authenticationStage == AuthenticationStage.needsPin) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Ключ сохранён'),
                      subtitle: Text(
                        'Провайдер: $provider\n'
                        'Требуется PIN для разблокировки.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go('/auth'),
                        child: const Text('Ввести PIN'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            context.read<AuthProvider>().resetAuth(),
                        child: const Text('Сбросить ключ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // authenticated
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Сессия активна'),
                    subtitle: Text('Провайдер: $provider'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/chat'),
                      child: const Text('Перейти в чат'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => context.read<AuthProvider>().resetAuth(),
                      child: const Text('Сменить ключ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Настройка провайдера'),
            actions: [
              const ThemeModeButton(),
              SettingsIconButton(),
              const SizedBox(width: 8),
            ],
            leading: IconButton(
              tooltip: 'На главную',
              icon: const Icon(Icons.home),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              // важно: даём дочернему виджету высоту экрана, чтобы Center мог центрировать по вертикали
              constraints: BoxConstraints(
                minHeight:
                    constraints.maxHeight - 32, // учли padding сверху/снизу
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    key: _providerContentKey,
                    child: stageBody(),
                  ),
                ),
              ),
            ),
          );
        },
          ),
        ),

        // Onboarding overlay
        if (_showOnboarding)
          OnboardingOverlay(
            targetKey: _providerContentKey,
            title: 'Настройка провайдера',
            description:
                'Здесь вы можете настроить API ключ для OpenRouter или VseGPT. Это необходимо для работы с AI моделями. После настройки ключа вам потребуется установить PIN-код для безопасности.',
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
