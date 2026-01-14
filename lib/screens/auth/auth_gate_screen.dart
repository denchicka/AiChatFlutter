import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'pin_entry_screen.dart';

/// AuthGateScreen - главный экран авторизации (роутинг между экранами)
///
/// Ответственность:
/// - Определение текущей стадии авторизации (AuthenticationStage)
/// - Отображение соответствующего экрана в зависимости от стадии
/// - Плавные переходы между экранами (PageTransitionSwitcher)
///
/// Стадии и соответствующие экраны:
/// - unknown: _AuthLoadingScreen (показ загрузки во время проверки)
/// - needsApiKey: _NeedKeyScreen (сообщение о необходимости ключа) или ApiKeyEntryScreen
/// - needsPin: PinEntryScreen (ввод PIN кода)
/// - authenticated: _AuthLoadingScreen (краткая загрузка перед переходом)
///
/// Навигация:
/// - При unknown: проверка сохранённых данных через AuthProvider
/// - При needsApiKey: перенаправление на /provider для ввода ключа
/// - При needsPin: показ PinEntryScreen
/// - При authenticated: роутер автоматически перенаправляет на /chat

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;
    _isInitialized = true;

    Future.microtask(() async {
      if (!mounted) return;
      context.read<AuthProvider>().initializeAuthenticationState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final Widget content = () {
      switch (auth.authenticationStage) {
        case AuthenticationStage.unknown:
          return const _AuthLoadingScreen();
        case AuthenticationStage.needsApiKey:
          // Ключ вводится на /provider
          return _NeedKeyScreen(onGo: () => context.go('/provider'));
        case AuthenticationStage.needsPin:
          return const PinEntryScreen();
        case AuthenticationStage.authenticated:
          return const _AuthLoadingScreen();
      }
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Разблокировка'),
        leading: IconButton(
          tooltip: 'На главную',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
            return FadeThroughTransition(
              animation: primaryAnimation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
          child: content,
        ),
      ),
    );
  }
}

class _NeedKeyScreen extends StatelessWidget {
  final VoidCallback onGo;
  const _NeedKeyScreen({required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ключ не настроен',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Text('Сначала добавьте API-ключ на странице настроек.'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onGo,
                    child: const Text('Перейти к настройке ключа'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}
