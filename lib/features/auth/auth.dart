// Auth feature module barrel.
//
// Модуль авторизации приложения:
// - Domain: бизнес-логика (определение провайдера, исключения)
// - Presentation: UI (экраны, провайдеры состояния)
//
// Структура:
// - domain/: бизнес-логика без зависимостей от Flutter
//   * ai_provider_detector.dart: определение типа провайдера по API ключу
//   * auth_exceptions.dart: исключения для обработки ошибок
// - presentation/screens/: экраны авторизации
//   * api_key_entry_screen.dart: ввод API ключа
//   * auth_gate_screen.dart: главный экран авторизации (роутинг)
//   * pin_entry_screen.dart: ввод PIN кода
// - presentation/providers/: провайдеры состояния
//   * auth_provider.dart: управление состоянием авторизации
//
// Зависимости:
// - Core: DatabaseService, AuthCryptoService, AuthBalanceClient
// - Routing: GoRouter для навигации

// Domain layer - бизнес-логика без зависимостей от Flutter
export 'domain/ai_provider_detector.dart';
export 'domain/auth_exceptions.dart';

// Presentation layer - UI компоненты
export '../../screens/auth/api_key_entry_screen.dart';
export '../../screens/auth/auth_gate_screen.dart';
export '../../screens/auth/pin_entry_screen.dart';
export '../../providers/auth_provider.dart';

// Примечание: старые файлы в lib/auth/ пока остаются для обратной совместимости
// После обновления всех импортов их можно будет удалить

