// Точка входа приложения AI Chat Flutter
//
// Основные компоненты:
// - Инициализация Flutter и загрузка конфигурации (.env)
// - Настройка окна для desktop платформ (Windows/Linux/macOS)
// - Настройка глобальной обработки ошибок
// - Инициализация провайдеров состояния (Provider)
// - Настройка роутинга (GoRouter)
//
// Архитектура:
// - RootApp: инициализирует провайдеры и роутер
// - MyApp: MaterialApp с темой и локализацией
// - ErrorBoundaryWidget: перехватывает ошибки рендеринга

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/database_service.dart';
import 'services/auth_crypto_service.dart';
import 'settings/settings_provider.dart';
import 'api/auth_balance_client.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'dart:async'; // для unawaited

import 'features/chat/chat.dart';
import 'features/auth/domain/ai_provider_detector.dart';

/// Настройка поведения скроллинга для всех устройств ввода
/// Поддерживает touch, mouse, trackpad, stylus для универсальности
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// Виджет-обертка для перехвата ошибок рендеринга
/// 
/// Если в дочернем виджете происходит ошибка:
/// - Логирует ошибку и стек-трейс в консоль
/// - Показывает экран с информацией об ошибке вместо краша приложения
/// 
/// Использование: оборачивает весь RootApp для глобальной защиты
class ErrorBoundaryWidget extends StatelessWidget {
  final Widget child;
  const ErrorBoundaryWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundaryWidget: $error');
          debugPrint('Stack trace: $stackTrace');
          // return MaterialApp(
          //   home: Scaffold(
          //     backgroundColor: Colors.red,
          //     body: Center(
          //       child: Padding(
          //         padding: const EdgeInsets.all(16.0),
          //         child: Text('Error: $error',
          //             style: const TextStyle(color: Colors.white)),
          //       ),
          //     ),
          //   ),
          // );
          return MaterialApp(
            scrollBehavior: const AppScrollBehavior(),
            theme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF1E1E1E),
              canvasColor: const Color(0xFF1E1E1E),
              colorScheme: const ColorScheme.dark(
                surface: Color(0xFF262626),
                surfaceTint: Colors.transparent,
              ),
              popupMenuTheme: const PopupMenuThemeData(
                color: Color(0xFF333333),
                surfaceTintColor: Colors.transparent,
              ),
              appBarTheme: const AppBarTheme(
                surfaceTintColor: Colors.transparent,
              ),
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Произошла ошибка',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(error.toString()),
                        const SizedBox(height: 10),
                        Text(stackTrace.toString()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Точка входа в приложение
/// 
/// Инициализация:
/// 1. Flutter binding (обязательно первым)
/// 2. Загрузка переменных окружения из .env
/// 3. Настройка окна для desktop (размер, позиция, заголовок)
/// 4. Глобальный обработчик ошибок Flutter
/// 5. Запуск приложения с ErrorBoundary для защиты от крашей
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Настройка окна для desktop платформ (Windows/Linux/macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1100, 760),        // Начальный размер окна
      minimumSize: Size(920, 640),  // Минимальный размер
      center: true,                  // Центрировать при открытии
      title: 'AI Chat',              // Заголовок окна
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Глобальный обработчик ошибок Flutter (логирование + показ в UI)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  runApp(const ErrorBoundaryWidget(child: RootApp()));
}

/// Корневой виджет приложения
/// 
/// Ответственность:
/// - Инициализация всех провайдеров состояния (Provider)
/// - Создание и настройка роутера (GoRouter)
/// - Связывание провайдеров между собой (например, ChatProvider зависит от AuthProvider)
/// 
/// Провайдеры:
/// - AuthProvider: управление авторизацией (API ключи, PIN)
/// - ThemeProvider: управление темой (светлая/темная/системная)
/// - SettingsProvider: настройки приложения
/// - ChatProvider: управление чатом (сообщения, модели, баланс)
class RootApp extends StatefulWidget {
  const RootApp({super.key});
  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  GoRouter? _router; // Роутер создается один раз и переиспользуется

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final p = AuthProvider(
              databaseService: DatabaseService(),
              authCryptoService: AuthCryptoService(),
              authBalanceClient: AuthBalanceClient(),
            );
            unawaited(p.initializeAuthenticationState());
            return p;
          },
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) {
            final t = ThemeProvider();
            unawaited(t.load());
            return t;
          },
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..init(),
        ),
        ChangeNotifierProvider<OnboardingProvider>(
          create: (_) {
            final o = OnboardingProvider();
            unawaited(o.load());
            return o;
          },
        ),
        // ChatProvider зависит от AuthProvider и SettingsProvider
        // Используем ChangeNotifierProxyProvider2 для автоматического обновления
        ChangeNotifierProxyProvider2<AuthProvider, SettingsProvider,
            ChatProvider>(
          create: (_) => ChatProvider(),
          update: (context, auth, settings, chat) {
            final p = chat!;

            // 1) Пробрасываем SettingsProvider внутрь ChatProvider
            //    (для доступа к настройкам уведомлений и другим опциям)
            p.setSettings(settings);

            // 2) Конфигурируем сессию по auth (если ключ/провайдер доступны)
            //    Это происходит автоматически при изменении AuthProvider
            if (auth.storedProviderType != null &&
                auth.decryptedApiKeyForSession != null) {
              final type = auth.storedProviderType!;
              final key = auth.decryptedApiKeyForSession!;
              final baseUri = AiProviderDetector.defaultBaseUri(type);

              // Важно: не await здесь — update должен быть синхронным
              // Используем unawaited для фоновой инициализации
              unawaited(
                p.configureSession(
                  providerType: type,
                  baseUri: baseUri,
                  apiKey: key,
                ),
              );
            }

            return p;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final onboardingProvider = context.read<OnboardingProvider>();
          _router ??= AppRouter.createRouter(
            authProvider: authProvider,
            onboardingProvider: onboardingProvider,
          );
          return MyApp(router: _router!);
        },
      ),
    );
  }
}

/// Основной виджет MaterialApp
/// 
/// Настройки:
/// - Роутинг через GoRouter (routerConfig)
/// - Локализация: русский (основной) и английский
/// - Темы: светлая и темная (переключение через ThemeProvider)
/// - Отключен debug banner в production
class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'AI Chat',
      locale: const Locale('ru', 'RU'), // Основной язык интерфейса
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),      // Светлая тема
      darkTheme: AppTheme.dark(),   // Темная тема
      themeMode: themeProvider.mode, // Режим темы (light/dark/system)
    );
  }
}
