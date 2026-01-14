// Модуль роутинга приложения (GoRouter)
//
// Ответственность:
// - Определение маршрутов приложения
// - Защита маршрутов (redirect логика)
// - Интеграция с AuthProvider для проверки авторизации
//
// Маршруты:
// - /home - главная страница
// - /provider - настройка API ключа
// - /auth - экран авторизации (PIN)
// - /chat - основной экран чата (требует авторизации)
// - /stats - статистика использования
// - /chart - график расходов по дням
// - /settings - настройки приложения
//
// Логика защиты:
// - /chat доступен только если есть провайдер И авторизация
// - /auth перенаправляет на /provider если ключа нет
// - /provider доступен всегда (для первичной настройки)

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

import '../screens/home_screen.dart';
import '../screens/provider_settings_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/daily_cost_chart_screen.dart';
import '../features/chat/chat.dart';
import '../screens/auth/auth_gate_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/onboarding/welcome_screen.dart';

class AppRouter {
  static GoRouter createRouter({
    required AuthProvider authProvider,
    required OnboardingProvider onboardingProvider,
  }) {
    return GoRouter(
      refreshListenable: authProvider,
      initialLocation: '/home',
      redirect: (BuildContext context, GoRouterState state) {
        final loc = state.matchedLocation;

        // Проверяем, нужно ли показать приветственный экран
        if (loc != '/welcome' && !onboardingProvider.welcomeCompleted) {
          return '/welcome';
        }

        // "/" не используем как страницу — просто ведём на home
        if (loc == '/') return '/home';

        // если пытаются открыть /auth, но ключа ещё нет — отправляем на настройки
        if (loc == '/auth' &&
            authProvider.authenticationStage ==
                AuthenticationStage.needsApiKey) {
          return '/provider';
        }

        final bool goingToChat = loc == '/chat';
        final bool hasProvider = authProvider.storedProviderType != null;

        // decryptedApiKeyForSession == null может значить и "нет ключа", и "ключ заблокирован"
        final bool isAuthenticated = authProvider.authenticationStage ==
            AuthenticationStage.authenticated;

        if (goingToChat) {
          if (!hasProvider) return '/provider';
          if (!isAuthenticated) return '/auth';
          return null;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/provider',
              builder: (context, state) => const ProviderSettingsScreen(),
            ),
            GoRoute(
              path: '/auth',
              builder: (context, state) => const AuthGateScreen(),
            ),
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsScreen(),
            ),
            GoRoute(
              path: '/chart',
              builder: (context, state) => const DailyCostChartScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
