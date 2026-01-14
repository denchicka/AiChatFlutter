import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../settings/settings_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../settings/notify_service.dart';
import '../../settings/changelog.dart';
import '../../settings/build_config.dart';
import '../../widgets/onboarding/onboarding_overlay.dart';

import '../../widgets/settings/section_card.dart';
import '../../widgets/settings/hover_tile.dart';
import '../../widgets/settings/toggle_tile.dart';
import '../../widgets/settings/updates_section.dart';
import '../../widgets/settings/theme_mode_picker.dart';
import '../../widgets/settings/notification_section.dart';
import '../../widgets/settings/status_line.dart';
import '../../widgets/settings/data_section.dart';
import '../../widgets/settings/info_callout.dart';
import '../../widgets/settings/info_step.dart';
import '../../widgets/top_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '—';

  // Ключи для onboarding
  final GlobalKey _settingsListKey = GlobalKey();
  final GlobalKey _notificationsCardKey = GlobalKey();
  final GlobalKey _dataCardKey = GlobalKey();
  bool _showOnboarding = false;
  bool _isScrollingToStep = false; // Флаг для отслеживания скролла
  int _onboardingStep = 0;

  // Шаги обучения для критичных элементов
  final List<_SettingsOnboardingStep> _onboardingSteps = [];

  // ScrollController для автоскролла к элементам обучения
  final ScrollController _scrollController = ScrollController();

  // controllers
  late final TextEditingController _tgTokenC;
  late final TextEditingController _tgChatIdC;

  late final TextEditingController _emailToC;
  late final TextEditingController _smtpHostC;
  late final TextEditingController _smtpPortC;
  late final TextEditingController _smtpUserC;
  late final TextEditingController _smtpPassC;

  bool _revealTgToken = false;
  bool _revealSmtpPass = false;

  CheckState _tgTestState = CheckState.idle;
  String? _tgTestMsg;

  CheckState _emailTestState = CheckState.idle;
  String? _emailTestMsg;

  @override
  void initState() {
    super.initState();

    _tgTokenC = TextEditingController();
    _tgChatIdC = TextEditingController();

    _emailToC = TextEditingController();
    _smtpHostC = TextEditingController();
    _smtpPortC = TextEditingController();
    _smtpUserC = TextEditingController();
    _smtpPassC = TextEditingController();

    _loadVersion();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      // Проверяем, что состояние загружено перед проверкой onboarding
      if (onboarding.loaded && onboarding.shouldShowOnboarding('settings')) {
        // Инициализируем шаги после загрузки настроек
        final sp = context.read<SettingsProvider>();
        // Ждем загрузки настроек, если они еще не загружены
        if (!sp.loaded) {
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (mounted) {
          _initializeOnboardingSteps(sp);

          setState(() {
            _showOnboarding = true;
          });

          // Скроллим к первому элементу обучения перед показом overlay
          // Используем двойной postFrameCallback для гарантии, что виджеты построены
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _onboardingSteps.isNotEmpty) {
                setState(() {
                  _isScrollingToStep = true;
                });
                _scrollToOnboardingStep(0, () {
                  if (mounted) {
                    setState(() {
                      _isScrollingToStep = false;
                    });
                  }
                });
              }
            });
          });
        }
      }
    });
  }

  void _initializeOnboardingSteps(SettingsProvider sp) {
    _onboardingSteps.clear();

    // Всегда показываем общее введение
    _onboardingSteps.add(
      _SettingsOnboardingStep(
        key: _settingsListKey,
        title: 'Настройки приложения',
        description:
            'Здесь вы можете настроить тему оформления, параметры чата, уведомления, обновления и другие параметры приложения.',
        position: TooltipPosition.top,
      ),
    );

    // Добавляем шаги только для критичных элементов, которые могут быть неочевидны
    // Уведомления - только если они включены
    // Проверяем sp.loaded, чтобы убедиться, что настройки загружены
    if (sp.loaded && sp.s.notifyOnAnswer) {
      _onboardingSteps.add(
        _SettingsOnboardingStep(
          key: _notificationsCardKey,
          title: 'Уведомления',
          description:
              'Настройте уведомления в Telegram или Email, чтобы получать сообщения о завершении ответов AI. Используйте кнопку "Тест" для проверки настроек.',
          position: TooltipPosition.top,
        ),
      );
      debugPrint(
          'Onboarding: Added notifications step (notifyOnAnswer: ${sp.s.notifyOnAnswer})');
    } else {
      debugPrint(
          'Onboarding: Skipped notifications step (loaded: ${sp.loaded}, notifyOnAnswer: ${sp.loaded ? sp.s.notifyOnAnswer : "N/A"})');
    }

    // Данные - всегда показываем, так как это важная функция
    _onboardingSteps.add(
      _SettingsOnboardingStep(
        key: _dataCardKey,
        title: 'Управление данными',
        description:
            'Здесь вы можете экспортировать историю чата, удалить данные или сбросить настройки. История сохраняется в папке Documents приложения.',
        position: TooltipPosition.top,
      ),
    );

    debugPrint('Onboarding: Initialized ${_onboardingSteps.length} steps');
  }

  void _onOnboardingNext() {
    if (_onboardingStep < _onboardingSteps.length - 1) {
      final nextStep = _onboardingStep + 1;
      // Временно скрываем overlay во время скролла
      setState(() {
        _isScrollingToStep = true;
      });

      // Скроллим к следующему элементу перед переходом
      _scrollToOnboardingStep(nextStep, () {
        if (mounted) {
          setState(() {
            _onboardingStep = nextStep;
            _isScrollingToStep = false;
          });
        }
      });
    } else {
      _completeOnboarding();
    }
  }

  /// Скроллит к целевому элементу обучения
  ///
  /// Использует Scrollable.ensureVisible с несколькими попытками для надежности
  Future<void> _scrollToOnboardingStep(
      int stepIndex, VoidCallback? onComplete) async {
    if (stepIndex >= _onboardingSteps.length || !mounted) {
      onComplete?.call();
      return;
    }

    final targetKey = _onboardingSteps[stepIndex].key;

    // Определяем, является ли элемент дальним (шаг 2+)
    final isFarElement = stepIndex >= 2;

    // Ждем, пока элемент появится в дереве виджетов
    // Для дальних элементов используем более длительное ожидание
    BuildContext? targetContext = targetKey.currentContext;
    int waitAttempts = 0;
    final maxWaitAttempts = isFarElement ? 40 : 30;

    while (targetContext == null && waitAttempts < maxWaitAttempts && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      targetContext = targetKey.currentContext;
      waitAttempts++;
    }

    // Если элемент все еще не найден и это дальний элемент,
    // делаем один плавный скролл вниз, чтобы элемент был построен
    // НО только если мы действительно ниже целевой позиции
    if (targetContext == null &&
        isFarElement &&
        _scrollController.hasClients &&
        mounted) {
      final currentOffset = _scrollController.offset;
      final maxScroll = _scrollController.position.maxScrollExtent;

      // Вычисляем примерную позицию элемента (предполагаем ~300px на элемент)
      final estimatedPosition = (stepIndex * 300.0).clamp(0.0, maxScroll);

      // Скроллим только вниз (если целевая позиция ниже текущей)
      // Это предотвратит скролл вверх
      if (estimatedPosition > currentOffset + 150) {
        debugPrint(
            'Onboarding step $stepIndex: Pre-scrolling down to position $estimatedPosition (current: $currentOffset)');
        await _scrollController.animateTo(
          estimatedPosition,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
        // Ждем, чтобы элемент был построен
        await Future.delayed(const Duration(milliseconds: 600));
        targetContext = targetKey.currentContext;
      }
    }

    if (targetContext == null || !mounted) {
      debugPrint(
          'Onboarding step $stepIndex: context not found after ${waitAttempts} attempts');
      onComplete?.call();
      return;
    }

    // Пробуем Scrollable.ensureVisible с несколькими попытками
    // Для дальних элементов (шаг 2+) используем более длительную анимацию
    final scrollDuration = isFarElement
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 1000);

    bool scrollSuccess = false;
    for (int attempt = 0;
        attempt < 10 && !scrollSuccess && mounted;
        attempt++) {
      // Обновляем контекст перед каждой попыткой
      targetContext = targetKey.currentContext;
      if (targetContext == null) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      try {
        // Для дальних элементов сначала делаем быстрый скролл, потом точный
        if (isFarElement && attempt == 0) {
          // Первая попытка для дальних элементов - быстрый скролл
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            alignment: 0.0, // Сначала просто показываем элемент
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Используем ensureVisible с более длительной анимацией для надежности
        await Scrollable.ensureVisible(
          targetContext,
          duration: scrollDuration,
          curve: Curves.easeInOutCubic,
          alignment: 0.25, // Позиционируем элемент на 25% от верха
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );

        // Ждем завершения анимации и проверяем видимость
        // Для дальних элементов ждем дольше
        await Future.delayed(isFarElement
            ? const Duration(milliseconds: 700)
            : const Duration(milliseconds: 500));

        // Проверяем, что элемент действительно виден
        final renderBox = targetContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.attached) {
          final position = renderBox.localToGlobal(Offset.zero);
          final screenHeight = MediaQuery.of(context).size.height;

          // Элемент виден, если его верхняя граница в пределах экрана
          // Используем более широкий диапазон для проверки
          if (position.dy >= -100 && position.dy < screenHeight + 100) {
            scrollSuccess = true;
            debugPrint(
                'Onboarding step $stepIndex: scroll successful on attempt ${attempt + 1}');
            break;
          } else {
            debugPrint(
                'Onboarding step $stepIndex: element not visible after scroll (position: ${position.dy}, screenHeight: $screenHeight)');
          }
        }
      } catch (e) {
        debugPrint(
            'Onboarding step $stepIndex: ensureVisible attempt ${attempt + 1} failed: $e');
        if (attempt < 9) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }

    // Если ensureVisible не сработал, пробуем через ScrollController
    if (!scrollSuccess && _scrollController.hasClients && mounted) {
      targetContext = targetKey.currentContext;
      if (targetContext != null) {
        try {
          final renderBox = targetContext.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.attached) {
            final globalPosition = renderBox.localToGlobal(Offset.zero);
            final screenHeight = MediaQuery.of(context).size.height;
            final appBarHeight = AppBar().preferredSize.height;
            final statusBarHeight = MediaQuery.of(context).padding.top;
            final availableHeight =
                screenHeight - appBarHeight - statusBarHeight;
            final currentScrollOffset = _scrollController.offset;

            // Вычисляем позицию элемента в списке
            final elementTopOnScreen =
                globalPosition.dy - statusBarHeight - appBarHeight;

            // Для элементов, которые не видны на экране, используем другой подход
            double elementTopInList;
            if (elementTopOnScreen < 0 ||
                elementTopOnScreen > availableHeight) {
              // Элемент не виден - используем приблизительный расчет
              // Для дальних элементов пробуем найти через размеры предыдущих элементов
              if (isFarElement) {
                // Для третьего шага и дальше используем более агрессивный скролл
                // Предполагаем, что элемент находится ниже текущей видимой области
                final estimatedOffset = currentScrollOffset +
                    (elementTopOnScreen < 0
                        ? elementTopOnScreen
                        : elementTopOnScreen - availableHeight);
                elementTopInList = estimatedOffset;
              } else {
                elementTopInList = elementTopOnScreen + currentScrollOffset;
              }
            } else {
              // Элемент виден - вычисляем его позицию в списке
              elementTopInList = elementTopOnScreen + currentScrollOffset;
            }

            final targetScrollOffset =
                elementTopInList - (availableHeight * 0.25);

            if (targetScrollOffset >= 0 &&
                targetScrollOffset <=
                    _scrollController.position.maxScrollExtent) {
              // Для дальних элементов используем более длительную анимацию
              await _scrollController.animateTo(
                targetScrollOffset,
                duration: isFarElement
                    ? const Duration(milliseconds: 1200)
                    : const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
              );
              await Future.delayed(isFarElement
                  ? const Duration(milliseconds: 600)
                  : const Duration(milliseconds: 400));

              // Финальная корректировка через ensureVisible
              final finalContext = targetKey.currentContext;
              if (finalContext != null && mounted) {
                try {
                  await Scrollable.ensureVisible(
                    finalContext,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    alignment: 0.25,
                    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                  );
                  await Future.delayed(const Duration(milliseconds: 300));
                } catch (_) {
                  // Игнорируем ошибки финальной корректировки
                }
              }
            } else {
              debugPrint(
                  'Onboarding step $stepIndex: targetScrollOffset out of range: $targetScrollOffset (max: ${_scrollController.position.maxScrollExtent})');
            }
          }
        } catch (e) {
          debugPrint('Onboarding step $stepIndex: direct scroll failed: $e');
        }
      }
    }

    // Вызываем callback после завершения скролла
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      onComplete?.call();
    }
  }

  void _onOnboardingSkip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.completeScreen('settings');

    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  @override
  void dispose() {
    _tgTokenC.dispose();
    _tgChatIdC.dispose();
    _emailToC.dispose();
    _smtpHostC.dispose();
    _smtpPortC.dispose();
    _smtpUserC.dispose();
    _smtpPassC.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _repeatOnboarding() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.resetAll();

    if (!mounted) return;

    // Переходим на экран приветствия, чтобы стартовать обучение заново
    context.go('/welcome');
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  void _toast(
    String text, {
    TopToastType type = TopToastType.info,
    int seconds = 2,
  }) {
    if (!mounted) return;

    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TopToast.show(
        rootCtx,
        text,
        type: type,
        duration: Duration(seconds: seconds),
      );
    });
  }

  void _setIfDiff(TextEditingController c, String v) {
    if (c.text == v) return;
    final sel = c.selection;
    final clamped = math.max(0, math.min(sel.baseOffset, v.length));
    c.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: clamped),
    );
  }

  bool _looksLikeEmail(String v) {
    final t = v.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  bool _looksLikeChatId(String v) {
    final t = v.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^-?\d+$').hasMatch(t);
  }

  Future<void> _showChangeLog() async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.40,
            maxChildSize: 0.92,
            builder: (ctx, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                children: [
                  Text(
                    'Что нового?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Версия: $_version',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...kChangeLog.map((e) {
                    final dt = e.parsedDate;
                    final dateLabel = dt == null ? e.date : formatDdMmYyyy(dt);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.version} • $dateLabel',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...e.items.asMap().entries.map((it) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InfoStep(
                                  index: it.key + 1,
                                  text: it.value,
                                ),
                              )),
                        ],
                      ),
                    );
                  }),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Закрыть'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _testTelegram(SettingsProvider sp) async {
    setState(() {
      _tgTestState = CheckState.running;
      _tgTestMsg = 'Проверка...';
    });

    try {
      await NotifyService.instance.sendTelegram(
        s: sp.s,
        text: 'Тестовое уведомление из приложения.',
      );
      if (!mounted) return;

      setState(() {
        _tgTestState = CheckState.ok;
        _tgTestMsg = 'ОК: сообщение отправлено';
      });

      _toast('Telegram: отправлено', type: TopToastType.success, seconds: 2);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _tgTestState = CheckState.error;
        _tgTestMsg = 'Ошибка: $e';
      });

      _toast('Telegram ошибка: $e', type: TopToastType.error, seconds: 4);
    }
  }

  Future<void> _testEmail(SettingsProvider sp) async {
    setState(() {
      _emailTestState = CheckState.running;
      _emailTestMsg = 'Проверка...';
    });

    try {
      await NotifyService.instance.sendEmail(
        s: sp.s,
        subject: 'Test notification',
        body: 'Test email from app.',
      );
      if (!mounted) return;

      setState(() {
        _emailTestState = CheckState.ok;
        _emailTestMsg = 'ОК: письмо отправлено';
      });

      _toast('Email: отправлено', type: TopToastType.success, seconds: 2);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _emailTestState = CheckState.error;
        _emailTestMsg = 'Ошибка: $e';
      });

      _toast('Email ошибка: $e', type: TopToastType.error, seconds: 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();

    if (!sp.loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final s = sp.s;

    // sync controllers
    _setIfDiff(_tgTokenC, s.telegramBotToken);
    _setIfDiff(_tgChatIdC, s.telegramChatId);

    _setIfDiff(_emailToC, s.emailTo);
    _setIfDiff(_smtpHostC, s.smtpHost);
    _setIfDiff(_smtpPortC, s.smtpPort.toString());
    _setIfDiff(_smtpUserC, s.smtpUsername);
    _setIfDiff(_smtpPassC, s.smtpPassword);

    // validation
    final tgTokenErr =
        s.notifyTelegramEnabled && s.telegramBotToken.trim().isEmpty
            ? 'Введите Bot Token'
            : null;
    final tgChatErr =
        s.notifyTelegramEnabled && !_looksLikeChatId(s.telegramChatId)
            ? 'Chat ID должен быть числом (для групп часто отрицательный)'
            : null;

    final emailToErr = s.notifyEmailEnabled && !_looksLikeEmail(s.emailTo)
        ? 'Введите корректный email получателя'
        : null;

    final smtpHostErr = s.notifyEmailEnabled && s.smtpHost.trim().isEmpty
        ? 'Введите SMTP host'
        : null;

    final smtpPort = int.tryParse(s.smtpPort.toString()) ?? 0;
    final smtpPortErr =
        s.notifyEmailEnabled && (smtpPort <= 0 || smtpPort > 65535)
            ? 'Порт должен быть 1–65535'
            : null;

    final smtpUserErr = s.notifyEmailEnabled && s.smtpUsername.trim().isEmpty
        ? 'Введите SMTP username (обычно ваш email)'
        : null;

    final smtpPassErr = s.notifyEmailEnabled && s.smtpPassword.trim().isEmpty
        ? 'Введите пароль приложения / SMTP пароль'
        : null;

    final canTestTg = tgTokenErr == null && tgChatErr == null;
    final canTestEmail = emailToErr == null &&
        smtpHostErr == null &&
        smtpPortErr == null &&
        smtpUserErr == null &&
        smtpPassErr == null;

    // Обновляем шаги обучения при изменении состояния уведомлений
    if (_showOnboarding && _onboardingSteps.isNotEmpty) {
      // Проверяем, нужно ли обновить шаги (например, если уведомления были включены/выключены)
      final hasNotificationsStep = _onboardingSteps.any(
        (step) => step.key == _notificationsCardKey,
      );

      // Находим индекс шага с уведомлениями, если он есть
      final notificationsStepIndex = _onboardingSteps.indexWhere(
        (step) => step.key == _notificationsCardKey,
      );

      // Если уведомления включены, но шага нет - добавляем
      // Добавляем только если мы еще не прошли этот шаг (или он первый)
      if (s.notifyOnAnswer && !hasNotificationsStep) {
        // Добавляем шаг после первого (введения), но только если мы на шаге 0 или 1
        if (_onboardingStep <= 1) {
          _onboardingSteps.insert(
            1,
            _SettingsOnboardingStep(
              key: _notificationsCardKey,
              title: 'Уведомления',
              description:
                  'Настройте уведомления в Telegram или Email, чтобы получать сообщения о завершении ответов AI. Используйте кнопку "Тест" для проверки настроек.',
              position: TooltipPosition.top,
            ),
          );
          debugPrint('Onboarding: Added notifications step dynamically');
        }
      }

      // Если уведомления выключены, но шаг есть - удаляем
      // Удаляем только если мы еще не дошли до этого шага
      if (!s.notifyOnAnswer &&
          hasNotificationsStep &&
          notificationsStepIndex >= 0) {
        // Удаляем только если текущий шаг меньше индекса шага с уведомлениями
        if (_onboardingStep < notificationsStepIndex) {
          _onboardingSteps.removeAt(notificationsStepIndex);
          debugPrint('Onboarding: Removed notifications step dynamically');
        }
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(title: const Text('Настройки')),
          body: ListView(
            controller: _scrollController,
            key: _settingsListKey,
            // Добавляем physics для более плавного скролла
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              SectionCard(
                title: 'Оформление',
                child: const ThemeModePicker(),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Чат',
                child: Column(
                  children: [
                    ToggleTile(
                      title: 'Показывать токены',
                      subtitle: 'Строка “Токенов: …” под сообщениями',
                      value: s.showTokensInChat,
                      onChanged: (v) =>
                          sp.update(s.copyWith(showTokensInChat: v)),
                    ),
                    Divider(height: 12, color: scheme.outlineVariant),
                    ToggleTile(
                      title: 'Показывать стоимость',
                      subtitle: 'Строка “Стоимость: …” под сообщениями',
                      value: s.showCostInChat,
                      onChanged: (v) =>
                          sp.update(s.copyWith(showCostInChat: v)),
                    ),
                    Divider(height: 12, color: scheme.outlineVariant),
                    ToggleTile(
                      title: 'Показывать источник/модель',
                      subtitle: 'Например: OpenRouter · gpt-4o-mini',
                      value: s.showModelInfoInChat,
                      onChanged: (v) =>
                          sp.update(s.copyWith(showModelInfoInChat: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Общее',
                child: Column(
                  children: [
                    HoverTile(
                      title: 'Версия приложения',
                      subtitle: _version,
                      trailing: Icon(Icons.info_outline,
                          color: scheme.onSurfaceVariant, size: 18),
                      onTap: _showChangeLog,
                    ),
                    const SizedBox(height: 10),
                    const InfoCallout(
                      icon: Icons.lock_outline,
                      title: 'Безопасность',
                      body: Text(
                        'Секреты (Bot Token / SMTP password) хранятся в Secure Storage.',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ВАЖНО: теперь тумблер “Уведомлять об ответе” внутри карточки (с фоном)
                    ToggleTile(
                      title: 'Уведомлять об ответе',
                      subtitle:
                          'Отправлять уведомление в Telegram / Email после ответа ассистента',
                      value: s.notifyOnAnswer,
                      onChanged: (v) =>
                          sp.update(s.copyWith(notifyOnAnswer: v)),
                    ),
                  ],
                ),
              ),

              // Если выключено — скрываем целиком “Уведомления”
              if (s.notifyOnAnswer) ...[
                const SizedBox(height: 16),
                SectionCard(
                  key: _notificationsCardKey,
                  title: 'Уведомления',
                  trailing: IconButton(
                    tooltip: 'Как работает',
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () {
                      InfoSheet.show(
                        context,
                        title: 'Уведомления: общий принцип',
                        child: const InfoCallout(
                          icon: Icons.info_outline,
                          title: 'Как работает',
                          body: Text(
                            '1) Включите «Уведомлять об ответе».\n'
                            '2) Включите Telegram или Email.\n'
                            '3) Заполните параметры.\n'
                            '4) Нажмите «Тест».\n'
                            '5) Если ошибка — исправьте поля и повторите.',
                          ),
                        ),
                      );
                    },
                  ),
                  child: NotificationSection(
                    sp: sp,

                    // Telegram
                    tgTokenC: _tgTokenC,
                    tgChatIdC: _tgChatIdC,
                    revealTgToken: _revealTgToken,
                    toggleRevealTgToken: () =>
                        setState(() => _revealTgToken = !_revealTgToken),
                    tgTokenErr: tgTokenErr,
                    tgChatErr: tgChatErr,
                    canTestTg: canTestTg && _tgTestState != CheckState.running,
                    onTestTelegram: () => _testTelegram(sp),
                    tgStatusLine:
                        StatusLine(state: _tgTestState, text: _tgTestMsg),

                    // Email
                    emailToC: _emailToC,
                    smtpHostC: _smtpHostC,
                    smtpPortC: _smtpPortC,
                    smtpUserC: _smtpUserC,
                    smtpPassC: _smtpPassC,
                    revealSmtpPass: _revealSmtpPass,
                    toggleRevealSmtpPass: () =>
                        setState(() => _revealSmtpPass = !_revealSmtpPass),
                    emailToErr: emailToErr,
                    smtpHostErr: smtpHostErr,
                    smtpPortErr: smtpPortErr,
                    smtpUserErr: smtpUserErr,
                    smtpPassErr: smtpPassErr,
                    canTestEmail:
                        canTestEmail && _emailTestState != CheckState.running,
                    onTestEmail: () => _testEmail(sp),
                    emailStatusLine:
                        StatusLine(state: _emailTestState, text: _emailTestMsg),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              SectionCard(
                title: 'Обновления',
                child: UpdatesSection(sp: sp),
              ),

              const SizedBox(height: 16),
              SectionCard(
                title: 'Обучение',
                child: HoverTile(
                  title: 'Повторить обучение',
                  subtitle:
                      'Сбрасывает прогресс обучения и вернёт на стартовый экран',
                  trailing: Icon(
                    Icons.school_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onTap: _repeatOnboarding,
                ),
              ),

              const SizedBox(height: 16),
              SectionCard(
                key: _dataCardKey,
                title: 'Данные',
                child: DataSection(
                  sp: sp,
                  snack: (msg, {seconds = 2}) =>
                      _toast(msg, type: TopToastType.info, seconds: seconds),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Поддержка',
                child: HoverTile(
                  title: 'Telegram создателя',
                  subtitle: 'Написать разработчику',
                  trailing: Icon(Icons.open_in_new,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18),
                  onTap: () async {
                    final uri = Uri.tryParse(BuildConfig.creatorTelegramUrl);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Onboarding overlay - показываем только после завершения скролла
        if (_showOnboarding &&
            !_isScrollingToStep &&
            _onboardingStep < _onboardingSteps.length)
          OnboardingOverlay(
            key: ValueKey('settings_onboarding_$_onboardingStep'),
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
  }
}

/// Шаг обучения для экрана настроек
class _SettingsOnboardingStep {
  final GlobalKey key;
  final String title;
  final String description;
  final TooltipPosition position;

  _SettingsOnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.position,
  });
}
