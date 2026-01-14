// Chat feature module barrel.
//
// Постепенно переносим файлы внутрь `features/chat/`, но чтобы ничего не ломалось,
// сначала делаем единый “вход” для импорта.
//
// ВНИМАНИЕ: chat provider и chat screen реализованы через `part of`,
// поэтому экспортируем только “основные” библиотеки. Parts подтянутся автоматически.

// Screens
export '../../screens/chat_screen.dart';

// Providers
export '../../providers/chat_provider.dart';

// Widgets
export 'widgets/chat/markdown_code_block_builder.dart';
export 'widgets/chat/typing_dots.dart';
export 'widgets/chat_analytics_sheet.dart';

// Utils
export '../../chat/domain/utils/cost_formatter.dart';
export '../../chat/domain/utils/provider_utils.dart';

