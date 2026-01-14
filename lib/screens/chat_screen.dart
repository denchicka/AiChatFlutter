import '../settings/settings_provider.dart';
// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с системными сервисами (буфер обмена)
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';

import '../widgets/theme_mode_button.dart';
import '../features/chat/widgets/models/model_sort.dart';
import '../widgets/top_toast.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding/onboarding_overlay.dart';

import 'dart:math' as math;
import 'package:flutter/gestures.dart';

// Импорт для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт провайдера чата и связанных компонентов (через barrel-файл)
import '../features/chat/chat.dart';
// Импорт модели сообщения
import '../models/message.dart';
import '../models/message_ext.dart';

import '../analytics/provider_ids.dart';

// ChatScreen - основной экран чата с ИИ
//
// Архитектура:
// - Использует ScrollablePositionedList для эффективной прокрутки больших списков
// - Разделён на части (part files) для модульности:
//   * chat_screen_aux_widgets.dart: вспомогательные виджеты (ErrorBoundary, BalanceChip)
//   * chat_screen_measure.dart: утилиты для измерения размеров
//   * chat_screen_markdown.dart: обработка markdown и LaTeX формул
//   * chat_screen_message_bubble.dart: виджет пузырька сообщения
//   * chat_screen_message_input.dart: поле ввода сообщения
//   * chat_screen_model_picker.dart: выбор модели в bottom sheet
//
// Функциональность:
// - Отображение истории сообщений с поддержкой markdown и LaTeX
// - Автоматическая прокрутка к новым сообщениям
// - Кнопка "вниз" при прокрутке вверх
// - Выбор модели через bottom sheet
// - Отображение баланса и метаданных сообщений
//
// Управление состоянием:
// - ChatProvider: управление сообщениями, моделями, балансом
// - SettingsProvider: настройки отображения (токены, стоимость, модель)
//
// Производительность:
// - Использует RepaintBoundary для оптимизации перерисовок
// - Lazy loading сообщений через ScrollablePositionedList
// - Кэширование markdown рендеринга

// Виджет для обработки ошибок в UI

part 'chat_screen_aux_widgets.dart';
part 'chat_screen_measure.dart';
part 'chat_screen_markdown.dart';
part 'chat_screen_message_bubble.dart';
part 'chat_screen_message_input.dart';
part 'chat_screen_model_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ItemScrollController _itemScroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  bool _showJump = false;
  bool _didInitialScroll = false;
  int _lastMsgLen = 0;
  bool _showUp = false;

  // Ключи для onboarding
  final GlobalKey _modelSelectorKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _messagesListKey = GlobalKey();
  final GlobalKey _inputAreaKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  int _onboardingStep = 0;
  bool _showOnboarding = false;

  final List<_ChatOnboardingStep> _onboardingSteps = [];

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onPositions);
    _initializeOnboardingSteps();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      // Проверяем, что состояние загружено перед проверкой onboarding
      if (onboarding.loaded && onboarding.shouldShowOnboarding('chat')) {
        setState(() {
          _showOnboarding = true;
        });
      }
    });
  }

  void _initializeOnboardingSteps() {
    _onboardingSteps.addAll([
      _ChatOnboardingStep(
        key: _modelSelectorKey,
        title: 'Выбор модели AI',
        description:
            'Нажмите здесь, чтобы выбрать модель искусственного интеллекта. Доступны различные модели с разными возможностями и стоимостью.',
        position: TooltipPosition.bottom,
      ),
      _ChatOnboardingStep(
        key: _balanceKey,
        title: 'Баланс',
        description:
            'Текущий баланс провайдера. Следите за расходом средств.',
        position: TooltipPosition.left, // Слева для лучшего отображения на мобильных
      ),
      _ChatOnboardingStep(
        key: _messagesListKey,
        title: 'История сообщений',
        description:
            'Здесь отображаются все ваши сообщения и ответы AI. Поддерживается форматирование markdown, код и формулы LaTeX.',
        position: TooltipPosition.top,
      ),
      _ChatOnboardingStep(
        key: _inputAreaKey,
        title: 'Поле ввода',
        description:
            'Введите ваше сообщение здесь. Нажмите Enter для отправки, Shift+Enter для новой строки. Используйте кнопку меню для дополнительных функций.',
        position: TooltipPosition.top,
      ),
      _ChatOnboardingStep(
        key: _menuKey,
        title: 'Дополнительные функции',
        description:
            'Меню: обновление, аналитика, экспорт истории, очистка чата.',
        position: TooltipPosition.left, // Слева для лучшего отображения на мобильных
      ),
      _ChatOnboardingStep(
        key: _inputAreaKey, // Используем то же поле ввода для подсказки о первом сообщении
        title: 'Отправьте свое первое сообщение',
        description:
            'Вы изумительны! Теперь попробуйте отправить свое первое сообщение AI. Просто введите текст и нажмите Enter или кнопку отправки.',
        position: TooltipPosition.top,
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
    await onboarding.completeScreen('chat');
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  void _onPositions() {
    final pos = _positions.itemPositions.value;
    if (pos.isEmpty) return;

    final maxIndex = pos.map((e) => e.index).reduce(math.max);
    final minIndex = pos.map((e) => e.index).reduce(math.min);

    final shouldShowDown = (_lastMsgLen > 0) && (maxIndex < _lastMsgLen - 2);
    final shouldShowUp = (_lastMsgLen > 0) && (minIndex > 1);

    if (shouldShowDown == _showJump && shouldShowUp == _showUp) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showJump = shouldShowDown;
        _showUp = shouldShowUp;
      });
    });
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _requestScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  void _scrollToIndex(int index) {
    if (!_itemScroll.isAttached) return;

    _itemScroll.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic, // Более плавная кривая как в Telegram
      alignment: 0.0,
    );
  }

  void _scrollToBottom({bool jump = false}) {
    final chat = context.read<ChatProvider>();
    final len = chat.messages.length;
    if (len == 0) return;

    final last = len - 1;

    if (!_itemScroll.isAttached) return;

    if (jump) {
      _itemScroll.jumpTo(index: last);
    } else {
      _itemScroll.scrollTo(
        index: last,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic, // Более плавная кривая как в Telegram
        alignment: 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final msg = chat.toastMessage;
        _lastMsgLen = chat.messages.length;

        final len = chat.messages.length;
        if (!_didInitialScroll && len > 0) {
          _didInitialScroll = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom(jump: true);
          });
        }

        final pending = chat.consumePendingScrollIndex();
        if (pending != null) {
          // ВАЖНО: иначе _buildMessagesList() в первый рендер утащит вниз
          _didInitialScroll = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToIndex(pending);
          });
        }
        if (msg != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final isErr = msg.startsWith('Ошибка') || msg.startsWith('Error');
            TopToast.show(
              context,
              msg,
              type: isErr ? TopToastType.error : TopToastType.info,
              duration: const Duration(seconds: 3),
            );
            chat.clearToast();
          });
        }

        return ErrorBoundary(
          child: Stack(
            children: [
              Scaffold(
                appBar: _buildAppBar(context),
                body: SafeArea(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            key: _messagesListKey,
                            child: _buildMessagesList(),
                          ),
                          _buildInputArea(context),
                        ],
                      ),

                      // кругляшок вниз
                      if (_showJump)
                        Positioned(
                          right: 12,
                          bottom: 72,
                          child: FloatingActionButton.small(
                            heroTag: 'jump_to_bottom',
                            elevation: 0,
                            highlightElevation: 0,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                            onPressed: () => _scrollToBottom(),
                            child:
                                const Icon(Icons.arrow_downward_rounded, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Onboarding overlay
              if (_showOnboarding && _onboardingStep < _onboardingSteps.length)
                OnboardingOverlay(
                  key: ValueKey('chat_onboarding_$_onboardingStep'),
                  targetKey: _onboardingSteps[_onboardingStep].key,
                  title: _onboardingSteps[_onboardingStep].title,
                  description: _onboardingSteps[_onboardingStep].description,
                  position: _onboardingSteps[_onboardingStep].position,
                  currentStep: _onboardingStep + 1,
                  totalSteps: _onboardingSteps.length,
                  onNext: _onOnboardingNext,
                  onSkip: _onOnboardingSkip,
                ),
            ],
          ),
        );
      },
    );
  }

  // Построение верхней панели приложения
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 48,
      leading: IconButton(
        tooltip: 'На главную',
        icon: const Icon(Icons.home, size: 18),
        onPressed: () => context.go('/home'),
      ),
      title: _buildModelSelector(context),
      actions: [
        const ThemeModeButton(),
        const SizedBox(width: 8),
        _buildBalanceDisplay(context),
        IconButton(
          tooltip: 'Настройки',
          icon: const Icon(Icons.settings, size: 18),
          onPressed: () => context.push('/settings'),
        ),
        _buildMenuButton(context),
        const SizedBox(width: 6),
      ],
    );
  }

  // Построение выпадающего списка для выбора модели
  Widget _buildModelSelector(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final scheme = Theme.of(context).colorScheme;

        Map<String, dynamic>? current;
        for (final m in chat.availableModels) {
          if ((m['id']?.toString() ?? '') == chat.currentModel) {
            current = m;
            break;
          }
        }

        final title = (current?['name'] ?? 'Выберите модель').toString();

        return SizedBox(
          key: _modelSelectorKey,
          width: MediaQuery.of(context).size.width * 0.52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon:
                Icon(Icons.smart_toy, size: 18, color: scheme.onSurfaceVariant),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();

              final selected = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: scheme.surface,
                builder: (_) => Consumer<ChatProvider>(
                  builder: (context, chat2, __) => _ModelPickerSheet(
                    models: chat2.availableModels,
                    currentId: chat2.currentModel,
                    initialFreeOnly: chat2.modelsFreeOnly,
                    onFreeOnlyChanged: chat2.setModelsFreeOnly,
                  ),
                ),
              );

              if (selected != null && selected != chat.currentModel) {
                chat.setCurrentModel(selected);
              }
            },
          ),
        );
      },
    );
  }

  // Отображение текущего баланса пользователя
  Widget _buildBalanceDisplay(BuildContext context) {
    return Container(
      key: _balanceKey,
      child: const BalanceChip(),
    );
  }

  // Построение кнопки меню с дополнительными опциями
  Widget _buildMenuButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      key: _menuKey,
      icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 18),
      color: scheme.surfaceContainerHighest,
      onSelected: (String choice) async {
        final chatProvider = context.read<ChatProvider>();
        switch (choice) {
          case 'refresh':
            await chatProvider.refreshAll(); // <-- добавим в ChatProvider
            if (context.mounted) {
              TopToast.show(context, 'Обновлено', type: TopToastType.success);
            }
            break;
          case 'analytics':
            _showAnalyticsSheet(context);
            break;
          case 'export':
            final path = await chatProvider.exportMessagesAsJson();
            if (context.mounted) {
              TopToast.show(context, 'История сохранена в: $path',
                  type: TopToastType.success);
            }
            break;
          case 'logs':
            final path = await chatProvider.exportLogs();
            if (context.mounted) {
              TopToast.show(context, 'Логи сохранены в: $path',
                  type: TopToastType.success);
            }
            break;
          case 'clear':
            _showClearHistoryDialog(context);
            break;
        }
      },
      itemBuilder: (BuildContext ctx) {
        final s = Theme.of(ctx).colorScheme;
        final itemStyle = TextStyle(color: s.onSurface, fontSize: 13);

        return [
          PopupMenuItem<String>(
            value: 'refresh',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18, color: s.onSurfaceVariant),
                const SizedBox(width: 10),
                Text('Обновить', style: itemStyle),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'analytics',
            height: 40,
            child: Text('Аналитика', style: itemStyle),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'export',
            height: 40,
            child: Text('Экспорт истории', style: itemStyle),
          ),
          PopupMenuItem<String>(
            value: 'logs',
            height: 40,
            child: Text('Скачать логи', style: itemStyle),
          ),
          PopupMenuItem<String>(
            value: 'clear',
            height: 40,
            child: Text('Очистить историю', style: itemStyle),
          ),
        ];
      },
    );
  }

  Future<DateTime?> _pickDateDialog(
      BuildContext context, DateTime initial) async {
    final scheme = Theme.of(context).colorScheme;

    DateTime selected = initial;

    final now = DateTime.now();
    final first = DateTime(2020);
    final last = now.add(const Duration(days: 3650));

    // initial должен быть в диапазоне
    if (selected.isBefore(first)) selected = first;
    if (selected.isAfter(last)) selected = last;

    return showDialog<DateTime>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHighest,
          title: const Text('Выберите дату'),
          content: SizedBox(
            width: 360,
            height: 360,
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: first,
              lastDate: last,
              onDateChanged: (d) => selected = d,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selected),
              child: const Text('Ок'),
            ),
          ],
        );
      },
    );
  }

  // Построение списка сообщений чата
  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Используем кастомный ScrollBehavior для поддержки перетаскивания мышкой
        // и корректной работы Scrollbar
        return ScrollConfiguration(
          // Кастомное поведение прокрутки с поддержкой мыши
          behavior: _CustomScrollBehavior(),
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScroll,
            itemPositionsListener: _positions,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];
            final prev = index > 0 ? chatProvider.messages[index - 1] : null;

            bool sameDay(DateTime a, DateTime b) =>
                a.year == b.year && a.month == b.month && a.day == b.day;

            final showDateChip =
                (prev == null || !sameDay(prev.createdAt, message.createdAt));

            Widget dateChip(DateTime d) {
              final scheme = Theme.of(context).colorScheme;

              const monthsRu = [
                'января',
                'февраля',
                'марта',
                'апреля',
                'мая',
                'июня',
                'июля',
                'августа',
                'сентября',
                'октября',
                'ноября',
                'декабря'
              ];

              final title = '${d.day} ${monthsRu[d.month - 1]}';

              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6), // ВНЕ клика
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior
                          .deferToChild, // кликаем только по “плашке”
                      onTap: () async {
                        final picked = await _pickDateDialog(context, d);
                        if (picked == null) return;
                        if (!context.mounted) return;
                        context
                            .read<ChatProvider>()
                            .requestScrollToDay(picked, emitToast: true);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDateChip) dateChip(message.createdAt),
                _MessageBubble(
                  message: message,
                  messages: chatProvider.messages,
                  index: index,
                  onRequestScrollToBottom: _requestScrollToBottom,
                ),
              ],
            );
          },
        ),
        );
      },
    );
  }

  // Построение области ввода сообщений
  Widget _buildInputArea(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: _inputAreaKey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: scheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: _MessageInput(
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  context.read<ChatProvider>().sendMessage(text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Отображение диалога подтверждения очистки истории
  void _showClearHistoryDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Очистить историю'),
          content: const Text('Вы уверены? Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await chatProvider.clearHistory();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Очистить'),
            ),
          ],
        );
      },
    );
  }
}

class _ChatOnboardingStep {
  final GlobalKey key;
  final String title;
  final String description;
  final TooltipPosition position;

  _ChatOnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.position,
  });
}

/// Кастомное поведение прокрутки для поддержки перетаскивания мышкой
/// и корректной работы Scrollbar с ScrollablePositionedList
class _CustomScrollBehavior extends MaterialScrollBehavior {
  /// Включаем поддержку перетаскивания мышкой для прокрутки
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  /// Переопределяем построение Scrollbar для корректной работы
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Используем Scrollbar с настройками для плавной работы как в Telegram
    // Проверяем наличие controller для корректной работы
    if (details.controller == null) {
      return child; // Если нет controller, возвращаем child без scrollbar
    }
    
    // Используем Scrollbar с настройками для плавной работы
    // Оборачиваем в Theme для кастомизации через ScrollbarTheme
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(6.0), // Более тонкий как в Telegram
          radius: const Radius.circular(3),
          minThumbLength: 40.0,
          crossAxisMargin: 2.0,
          mainAxisMargin: 4.0,
        ),
      ),
      child: Scrollbar(
        controller: details.controller!,
        // Автоматическое скрытие при бездействии
        thumbVisibility: false,
        // Включаем интерактивность для работы с мышкой
        interactive: true,
        child: child,
      ),
    );
  }
}
