class ChangeLogEntry {
  final String version;
  final String date; // DD-MM-YYYY
  final List<String> items;

  const ChangeLogEntry({
    required this.version,
    required this.date,
    required this.items,
  });

  DateTime? get parsedDate => _parseDdMmYyyy(date);

  static DateTime? _parseDdMmYyyy(String raw) {
    final t = raw.trim();
    final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(t);
    if (m == null) return null;

    final dd = int.tryParse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!);
    final yyyy = int.tryParse(m.group(3)!);
    if (dd == null || mm == null || yyyy == null) return null;

    // базовая валидация
    if (mm < 1 || mm > 12) return null;
    if (dd < 1 || dd > 31) return null;

    return DateTime(yyyy, mm, dd);
  }
}

String formatDdMmYyyy(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  return '$dd-$mm-$yyyy';
}

// История изменений приложения
const kChangeLog = <ChangeLogEntry>[
  ChangeLogEntry(
    version: '0.1.0',
    date: '05-01-2026',
    items: [
      'Базовый экран чата: список сообщений, поле ввода, отправка сообщений',
      'Сохранение истории сообщений в локальную БД (SQLite) и загрузка при старте',
      'Подключение провайдеров (OpenRouter / VseGPT) и выбор модели',
      'Отображение баланса провайдера в AppBar',
    ],
  ),
  ChangeLogEntry(
    version: '0.2.0',
    date: '05-01-2026',
    items: [
      'Markdown-рендер сообщений: ссылки, inline-код и блоки кода',
      'SelectionArea для корректного выделения текста без конфликтов с Markdown',
      'Кнопка копирования текста ответа с преобразованием Markdown → plain text',
      'Визуальный typing-индикатор (… / TypingDots) для ответа ассистента',
    ],
  ),
  ChangeLogEntry(
    version: '0.3.0',
    date: '06-01-2026',
    items: [
      'Поддержка LaTeX в сообщениях',
      'Авто-детект формул и безопасные эвристики (фильтрация мусорных выражений)',
      'Копируемые блок-формулы: карточка “Формула”, раскрытие LaTeX (+/−), копирование LaTeX',
      'Авто-конвертация Unicode-математики в TeX (c² → c^{2}, x₁ → x_{1}, √100 → \\sqrt{100})',
    ],
  ),
  ChangeLogEntry(
    version: '0.4.0',
    date: '06-01-2026',
    items: [
      'Схлопывание длинных ответов ассистента',
      'Fade-градиент и кнопка “Показать полностью / Свернуть” для больших сообщений',
      'Оптимизация измерения высоты контента',
    ],
  ),
  ChangeLogEntry(
    version: '0.5.0',
    date: '07-01-2026',
    items: [
      'Улучшена навигация по чату + умный “jump to bottom”',
      'Плашки дат между сообщениями + переход к дате',
      'Сервисная навигация: скролл к сообщению по uid/индексу/дню и по критериям (модель/провайдер/диапазон)',
    ],
  ),
  ChangeLogEntry(
    version: '0.6.0',
    date: '08-01-2026',
    items: [
      'Поиск, сортировка (цена/контекст/алфавит) и расширенные фильтры в выборе моделей',
      'Отдельное запоминание последней выбранной модели для OpenRouter и VseGPT',
      'Баланс: форматирование отрицательных значений для OpenRouter (-\$0.02) и подсказка про allowance',
      'Улучшение устойчивости запросов: stream-режим с throttling обновлений UI и fallback на non-stream при ошибках/таймаутах',
      'Отмена генерации пользователем: корректное завершение ответа и обновление баланса',
      'Учет токенов/стоимости в истории и “ремонт” providerId для старых сообщений по pricedAsVseGpt',
      'Повтор генерации (regenerate) с созданием нового варианта ответа и переключением active-variant',
      'Исправлена логика расчёта maxTokens в regenerate: лимит считается по реальному prompt (псевдо-чат контекст)',
      'Уведомления “по готовности ответа” (Telegram/Email) с фильтрацией ошибок и пустых ответов',
    ],
  ),
  ChangeLogEntry(
    version: '0.7.0',
    date: '09-01-2026',
    items: [
      'Экран аналитики: статистика использования по моделям и провайдерам',
      'График расходов по дням с фильтрацией по датам',
      'Экспорт истории чата в JSON формат',
      'Улучшенная система навигации между экранами',
    ],
  ),
  ChangeLogEntry(version: '0.8.0', date: '09-01-2026', items: [
    'Система обучения для новых пользователей',
    'Интерактивные подсказки с подсветкой элементов интерфейса',
    'Экран настроек: тема, уведомления, обновления, данные',
    'Поддержка темной и светлой темы с автоматическим переключением',
  ]),
  ChangeLogEntry(
    version: '0.9.0',
    date: '12-01-2026',
    items: [
      'Безопасное хранение API-ключей в Secure Storage',
      'PIN-код для защиты доступа к приложению',
      'Улучшенная обработка ошибок и сетевых проблем',
      'Оптимизация производительности и использования памяти',
    ],
  ),
  ChangeLogEntry(
    version: '1.0.0',
    date: '14-01-2026',
    items: [
      'Первый релиз версии 1.0.0',
      'Система автообновлений через GitHub Releases',
      'Улучшенная документация и комментарии в коде',
      'Исправлены все критические ошибки и предупреждения',
      'Оптимизация UI/UX на всех платформах',
      'Поддержка всех основных функций для работы с AI',
    ],
  ),
];
