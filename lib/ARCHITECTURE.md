# Архитектура приложения AI Chat Flutter

## Общая структура

Приложение использует **feature-first** архитектуру с разделением на слои внутри каждой фичи.

### Основные модули

```
lib/
├── main.dart                    # Точка входа, инициализация провайдеров и роутера
├── core/                        # Ядро приложения (общие компоненты)
│   └── core.dart               # Barrel файл для экспорта core модулей
├── features/                   # Функциональные модули
│   ├── auth/                   # Модуль авторизации
│   │   ├── domain/            # Бизнес-логика (без зависимостей от Flutter)
│   │   │   ├── ai_provider_detector.dart
│   │   │   └── auth_exceptions.dart
│   │   ├── presentation/      # UI компоненты
│   │   │   ├── screens/       # Экраны авторизации
│   │   │   └── providers/    # Провайдеры состояния
│   │   └── auth.dart         # Barrel файл для экспорта auth модуля
│   ├── chat/                  # Модуль чата
│   │   └── chat.dart         # Barrel файл для экспорта chat модуля
│   └── settings/             # Модуль настроек
│       └── settings.dart     # Barrel файл для экспорта settings модуля
├── providers/                 # Провайдеры состояния (пока в корне, постепенно переносятся)
├── screens/                  # Экраны (пока в корне, постепенно переносятся)
├── services/                  # Сервисы (общие для всего приложения)
├── models/                   # Модели данных
├── api/                      # API клиенты
├── widgets/                  # Переиспользуемые виджеты
├── routing/                  # Роутинг (GoRouter)
└── theme/                    # Темы приложения
```

## Модули

### Core (lib/core/)

Общие компоненты, используемые во всех модулях:
- **API клиенты**: `AiChatClient`, `OpenRouterApiClient`, `VseGptApiClient`, `AuthBalanceClient`
- **Модели**: `ChatMessage`, `MessageExt`
- **Сервисы**: `DatabaseService`, `AnalyticsService`, `AuthCryptoService`
- **Настройки**: `SettingsProvider`, `AppSettings`, `NotifyService`, `UpdateService`
- **Роутинг**: `AppRouter`
- **Темы**: `AppTheme`

### Features

#### Auth (lib/features/auth/)

Модуль авторизации:
- **Domain**: бизнес-логика без зависимостей от Flutter
  - `AiProviderDetector`: определение типа провайдера по API ключу
  - `AuthException`: исключения для обработки ошибок
- **Presentation**: UI компоненты
  - `ApiKeyEntryScreen`: ввод API ключа
  - `AuthGateScreen`: главный экран авторизации (роутинг)
  - `PinEntryScreen`: ввод PIN кода
  - `AuthProvider`: управление состоянием авторизации

#### Chat (lib/features/chat/)

Модуль чата (в процессе рефакторинга):
- **Presentation**: UI компоненты
  - `ChatScreen`: основной экран чата
  - `ChatProvider`: управление состоянием чата
- **Data**: работа с данными (частично в `chat/data/`)
- **Domain**: бизнес-логика (частично в `chat/domain/`)

#### Settings (lib/features/settings/)

Модуль настроек:
- **Presentation**: UI компоненты
  - `SettingsScreen`: экран настроек
  - Виджеты настроек в `widgets/settings/`

## Провайдеры состояния

### AuthProvider

Управление авторизацией:
- Хранение и проверка API ключей
- Генерация и проверка PIN кода
- Управление жизненным циклом авторизации (stages)

### ChatProvider

Управление чатом:
- Сообщения и история
- Модели и баланс
- Отправка запросов к API
- Статистика использования

Архитектура ChatProvider:
- `_ChatProviderBase`: базовый класс с общими полями
- Миксины разделяют функциональность:
  - `_ChatProviderSession`: управление сессией
  - `_ChatProviderScrolling`: управление прокруткой
  - `_ChatProviderData`: работа с данными
  - `_ChatProviderRequests`: отправка запросов
  - `_ChatProviderActions`: действия пользователя

### ThemeProvider

Управление темой приложения (светлая/темная/системная).

### SettingsProvider

Управление настройками приложения.

## Сервисы

### DatabaseService

Работа с локальной SQLite базой данных:
- Хранение истории сообщений
- Хранение зашифрованных данных авторизации
- Миграции схемы БД

### AnalyticsService

Сбор и анализ статистики использования:
- Отслеживание использования моделей
- Сбор данных о сессии
- Расчет метрик эффективности

### AuthCryptoService

Криптографические операции:
- Шифрование/дешифрование API ключей
- Хеширование PIN кодов
- Управление ключами шифрования

## Роутинг

### AppRouter

Маршруты приложения:
- `/home` - главная страница
- `/provider` - настройка API ключа
- `/auth` - экран авторизации (PIN)
- `/chat` - основной экран чата (требует авторизации)
- `/stats` - статистика использования
- `/chart` - график расходов по дням
- `/settings` - настройки приложения

Логика защиты:
- `/chat` доступен только если есть провайдер И авторизация
- `/auth` перенаправляет на `/provider` если ключа нет

## Примечания

### Утилиты

#### CostFormatter (`lib/chat/domain/utils/cost_formatter.dart`)

Централизованное форматирование стоимости для всех провайдеров:
- `formatCost()` - форматирование для UI (поддержка FREE, tiny costs, валют)
- `formatCostForProvider()` - форматирование для аналитики с фильтром провайдера

**Пример использования**:
```dart
// В UI компонентах
final costText = CostFormatter.formatCost(
  message.cost,
  providerId: message.providerId,
);

// В аналитике
final costText = CostFormatter.formatCostForProvider(
  totals.cost,
  pf: ProviderFilter.openrouter,
);
```

#### ProviderUtils (`lib/chat/domain/utils/provider_utils.dart`)

Утилиты для работы с провайдерами:
- `providerTypeFromId()` - конвертация ProviderIds → AiProviderType
- `providerIdFromType()` - конвертация AiProviderType → ProviderIds
- `inferProviderIdFromMessage()` - определение провайдера из сообщения (с fallback)
- `providerLabel()` - человекочитаемое название провайдера

**Пример использования**:
```dart
// Определение провайдера из сообщения
final providerId = ProviderUtils.inferProviderIdFromMessage(
  providerId: message.providerId,
  pricedAsVseGpt: message.pricedAsVseGpt,
);

// Получение названия провайдера
final label = ProviderUtils.providerLabel(providerId);
```

### Рефакторинг (выполнено)

✅ **Вынесена дублирующаяся логика**:
- Форматирование стоимости → `CostFormatter`
- Определение провайдера → `ProviderUtils` (использует `AiProviderDetector`)
- Расчёт стоимости → централизован через `CostCalculator` в `ChatProvider`

✅ **Унифицированы импорты**:
- Все импорты `AiProviderDetector` используют `features/auth/domain/ai_provider_detector.dart`
- Удалён дублирующий файл `lib/auth/ai_provider_detector.dart`

✅ **Исправлены deprecated API**:
- Radio API в `theme_mode_button.dart` обновлён на `RadioGroup`

### TODO

- [ ] Перенести все файлы чата в модульную структуру (features/chat/)
- [ ] Обновить все импорты для использования barrel файлов (частично выполнено)
- [x] Вынести дублирующуюся логику в общие утилиты
- [ ] Добавить больше комментариев в сложные места
- [x] Исправить deprecated Radio API в `theme_mode_button.dart`
