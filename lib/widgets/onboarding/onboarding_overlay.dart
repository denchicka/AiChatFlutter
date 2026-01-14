import 'package:flutter/material.dart';

/// Виджет для подсветки и обучения пользователя
/// 
/// Создает затемнение экрана с подсветкой определенной области
/// Показывает подсказку с текстом и кнопками навигации
class OnboardingOverlay extends StatefulWidget {
  /// Глобальный ключ элемента, который нужно подсветить
  final GlobalKey targetKey;
  
  /// Текст подсказки
  final String title;
  final String? description;
  
  /// Позиция подсказки относительно подсвеченного элемента
  final TooltipPosition position;
  
  /// Callback при нажатии "Далее"
  final VoidCallback? onNext;
  
  /// Callback при нажатии "Пропустить"
  final VoidCallback? onSkip;
  
  /// Показывать ли кнопку "Пропустить"
  final bool showSkip;
  
  /// Текущий шаг (для индикатора прогресса)
  final int currentStep;
  
  /// Общее количество шагов
  final int totalSteps;

  const OnboardingOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    this.description,
    this.position = TooltipPosition.bottom,
    this.onNext,
    this.onSkip,
    this.showSkip = true,
    this.currentStep = 1,
    this.totalSteps = 1,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _transitionController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<Rect?> _targetRectAnimation;

  Rect? _targetRect;
  Rect? _previousTargetRect; // Для плавного перехода
  Offset? _tooltipPosition;
  GlobalKey? _lastTargetKey;
  TooltipPosition? _actualPosition; // Фактически используемая позиция после адаптации
  Size? _tooltipSize; // фактический размер подсказки
  final GlobalKey _tooltipKey = GlobalKey();
  
  // Стабильные координаты для плавного перемещения
  double _stableLeft = 0.0;
  double _stableTop = 0.0;

  @override
  void initState() {
    super.initState();

    // Контроллер для пульсации подсветки (раз в секунду)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Контроллер для волн (ripple effect) - более медленный и мягкий
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    // Контроллер для плавного перехода затемнения между элементами
    // Увеличена длительность для профессионального motion design эффекта
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Легкая пульсация подсветки (от 1.0 до 1.05)
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Анимация волн (от 0 до 1)
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Curves.easeOut,
      ),
    );

    // Анимация перехода затемнения от одного элемента к другому
    // Инициализируем позже, когда будет известен первый targetRect
    _targetRectAnimation = AlwaysStoppedAnimation<Rect?>(null);

    _pulseController.repeat(reverse: true);
    _pulseAnimation.addListener(() => setState(() {}));
    _rippleAnimation.addListener(() => setState(() {}));
    _targetRectAnimation.addListener(() => setState(() {}));

    // Вычисляем позицию после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetPosition();
      _updateTooltipSize();
    });
  }


  @override
  void didUpdateWidget(OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если изменился targetKey или шаг, обновляем позицию с плавным переходом
    if (oldWidget.targetKey != widget.targetKey || 
        oldWidget.currentStep != widget.currentStep) {
      // Сохраняем предыдущий ключ для плавного перехода
      final wasDifferentKey = oldWidget.targetKey != widget.targetKey;
      if (wasDifferentKey) {
        // Не сбрасываем _lastTargetKey сразу, чтобы сохранить предыдущий Rect для анимации
        // _lastTargetKey будет обновлен в _updateTargetPosition после начала анимации
      }
      // НЕ сбрасываем контроллер здесь - он будет сброшен в _updateTargetPosition
      // Это обеспечивает плавный переход без прерывания
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTargetPosition();
        _updateTooltipSize();
      });
    }
  }

  void _updateTooltipSize() {
    final renderBox = _tooltipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      if (_tooltipSize != size) {
        // Обновляем размер, но не пересчитываем позицию сразу
        _tooltipSize = size;
        // Пересчитываем позицию только если она еще не установлена
        if (_tooltipPosition == null) {
          _calculateTooltipPosition();
        }
      }
    } else {
      // Пробуем позже
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _updateTooltipSize();
      });
    }
  }

  void _updateTargetPosition() {
    // Проверяем, не обновляем ли мы уже тот же элемент
    if (_lastTargetKey == widget.targetKey && _targetRect != null && !_transitionController.isAnimating) {
      return;
    }

    final renderBox = widget.targetKey.currentContext?.findRenderObject()
        as RenderBox?;

    if (renderBox == null || !renderBox.hasSize) {
      // Пробуем еще раз через небольшую задержку
      // Используем несколько попыток для надежности
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _updateTargetPosition();
      });
      return;
    }

    final size = renderBox.size;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final position = overlayBox == null
        ? renderBox.localToGlobal(Offset.zero)
        : renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);

    final isModelSelector =
        widget.title.contains('модел') || widget.title.contains('AI');
    final isHomeStatus = widget.title.contains('Статус системы');
    final isChart = widget.title.contains('График расходов');
    final isProvider = widget.title.contains('Настройка провайдера');

    final baseRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    final inflateBy = isModelSelector
        ? 6.0
        : (isHomeStatus || isChart || isProvider ? 4.0 : 0.0);
    final newRect = inflateBy > 0 ? baseRect.inflate(inflateBy) : baseRect;

    // Если это новый элемент, сохраняем предыдущий для плавного перехода
    if (_targetRect != null && _lastTargetKey != widget.targetKey) {
      _previousTargetRect = _targetRect;
      // Запускаем анимацию перехода затемнения с профессиональной кривой
      // Используем кастомную кривую для плавного скольжения вниз
      _targetRectAnimation = _RectTween(
        begin: _previousTargetRect!,
        end: newRect,
      ).animate(
        CurvedAnimation(
          parent: _transitionController,
          // Используем кривую для плавного профессионального движения
          // Эта кривая обеспечивает плавное ускорение и замедление для motion design эффекта
          curve: Curves.easeInOutCubic,
        ),
      );
      // Сбрасываем и запускаем анимацию заново для плавного перехода
      _transitionController.reset();
      _transitionController.forward();
      
      // Обновляем текущий Rect сразу, чтобы затемнение всегда покрывало экран
      setState(() {
        _targetRect = newRect;
        _lastTargetKey = widget.targetKey;
      });
      
      // Позицию tooltip обновляем после небольшой задержки для плавности
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateTooltipPosition();
        }
      });
    } else if (_targetRect == null) {
      // Первая установка - сразу показываем без анимации
      _targetRectAnimation = AlwaysStoppedAnimation<Rect?>(newRect);
      setState(() {
        _targetRect = newRect;
        _lastTargetKey = widget.targetKey;
        _calculateTooltipPosition();
      });
    } else {
      // Тот же элемент - обновляем анимацию на текущий Rect
      _targetRectAnimation = AlwaysStoppedAnimation<Rect?>(newRect);
      setState(() {
        _targetRect = newRect;
        _lastTargetKey = widget.targetKey;
        _calculateTooltipPosition();
      });
    }
  }

  void _calculateTooltipPosition() {
    if (_targetRect == null) return;

    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final safeAreaLeft = MediaQuery.of(context).padding.left;
    final safeAreaRight = MediaQuery.of(context).padding.right;
    final isMobile = screenSize.width < 600;
    final padding = isMobile ? 12.0 : 16.0;
    final tooltipSpacing = isMobile ? 8.0 : 12.0;
    
    // Адаптивный размер tooltip для мобильных устройств
    // Уменьшаем размер для компактности на маленьких экранах
    // Учитываем safe area для правильного расчета доступного пространства
    final availableScreenWidth = screenSize.width - safeAreaLeft - safeAreaRight;
    final estimatedTooltipWidth = isMobile 
        ? (availableScreenWidth * 0.85).clamp(260.0, 360.0)
        : 320.0;
    final estimatedTooltipHeight = isMobile ? 160.0 : 180.0;

    // Пробуем позицию согласно указанной
    Offset? preferredPosition;
    switch (widget.position) {
      case TooltipPosition.top:
        preferredPosition = Offset(
          _targetRect!.center.dx,
          _targetRect!.top - tooltipSpacing,
        );
        break;
      case TooltipPosition.bottom:
        preferredPosition = Offset(
          _targetRect!.center.dx,
          _targetRect!.bottom + tooltipSpacing,
        );
        break;
      case TooltipPosition.left:
        preferredPosition = Offset(
          _targetRect!.left - tooltipSpacing,
          _targetRect!.center.dy,
        );
        break;
      case TooltipPosition.right:
        preferredPosition = Offset(
          _targetRect!.right + tooltipSpacing,
          _targetRect!.center.dy,
        );
        break;
    }

    // Адаптивное позиционирование - выбираем лучшую позицию
    // Учитываем safe area для правильного расчета доступного пространства
    final availableSpaceTop = _targetRect!.top - padding - safeAreaTop;
    final availableSpaceBottom = screenSize.height - _targetRect!.bottom - padding - safeAreaBottom;
    final availableSpaceLeft = _targetRect!.left - padding - safeAreaLeft;
    final availableSpaceRight = screenSize.width - _targetRect!.right - padding - safeAreaRight;

    // Определяем лучшую позицию на основе доступного пространства
    // Приоритет: избегаем перекрытия важного контента (особенно для истории сообщений)
    TooltipPosition bestPosition = widget.position;
    double maxSpace = 0;

    // Для истории сообщений и выбора модели предпочитаем позицию снизу или сбоку, чтобы не перекрывать контент
    final isMessagesList = widget.title.contains('История сообщений') || 
                          widget.title.contains('сообщений');
    final isModelSelector = widget.title.contains('модел') || 
                          widget.title.contains('AI');
    final isInputField = widget.title.contains('Поле ввода') || 
                        widget.title.contains('первое сообщение');
    
    if (isMessagesList || isModelSelector || isInputField) {
      // Для истории сообщений, выбора модели и поля ввода приоритет: bottom > left > right > top
      // Это предотвращает перекрытие важного контента
      // Для поля ввода особенно важно не перекрывать прозрачную область
      if (isInputField) {
        // Для поля ввода предпочитаем top, но только если есть достаточно места
        if (availableSpaceTop >= estimatedTooltipHeight + 20) { // +20 для запаса
          bestPosition = TooltipPosition.top;
          maxSpace = availableSpaceTop;
        } else if (availableSpaceBottom >= estimatedTooltipHeight) {
          bestPosition = TooltipPosition.bottom;
          maxSpace = availableSpaceBottom;
        } else if (availableSpaceLeft >= estimatedTooltipWidth) {
          bestPosition = TooltipPosition.left;
          maxSpace = availableSpaceLeft;
        } else if (availableSpaceRight >= estimatedTooltipWidth) {
          bestPosition = TooltipPosition.right;
          maxSpace = availableSpaceRight;
        }
      } else {
        // Для истории сообщений и выбора модели
        if (availableSpaceBottom >= estimatedTooltipHeight) {
          bestPosition = TooltipPosition.bottom;
          maxSpace = availableSpaceBottom;
        } else if (availableSpaceLeft >= estimatedTooltipWidth) {
          bestPosition = TooltipPosition.left;
          maxSpace = availableSpaceLeft;
        } else if (availableSpaceRight >= estimatedTooltipWidth) {
          bestPosition = TooltipPosition.right;
          maxSpace = availableSpaceRight;
        } else if (availableSpaceTop >= estimatedTooltipHeight) {
          bestPosition = TooltipPosition.top;
          maxSpace = availableSpaceTop;
        }
      }
    } else {
      // Для других элементов используем стандартную логику
      if (availableSpaceTop > maxSpace && availableSpaceTop >= estimatedTooltipHeight) {
        maxSpace = availableSpaceTop;
        bestPosition = TooltipPosition.top;
      }
      if (availableSpaceBottom > maxSpace && availableSpaceBottom >= estimatedTooltipHeight) {
        maxSpace = availableSpaceBottom;
        bestPosition = TooltipPosition.bottom;
      }
      if (availableSpaceLeft > maxSpace && availableSpaceLeft >= estimatedTooltipWidth) {
        maxSpace = availableSpaceLeft;
        bestPosition = TooltipPosition.left;
      }
      if (availableSpaceRight > maxSpace && availableSpaceRight >= estimatedTooltipWidth) {
        maxSpace = availableSpaceRight;
        bestPosition = TooltipPosition.right;
      }
    }

    // Если предпочтительная позиция не подходит, используем лучшую
    final useBestPosition = (bestPosition != widget.position) &&
        ((widget.position == TooltipPosition.top && availableSpaceTop < estimatedTooltipHeight) ||
         (widget.position == TooltipPosition.bottom && availableSpaceBottom < estimatedTooltipHeight) ||
         (widget.position == TooltipPosition.left && availableSpaceLeft < estimatedTooltipWidth) ||
         (widget.position == TooltipPosition.right && availableSpaceRight < estimatedTooltipWidth));

    if (useBestPosition) {
      switch (bestPosition) {
        case TooltipPosition.top:
          preferredPosition = Offset(
            _targetRect!.center.dx,
            _targetRect!.top - tooltipSpacing,
          );
          break;
        case TooltipPosition.bottom:
          preferredPosition = Offset(
            _targetRect!.center.dx,
            _targetRect!.bottom + tooltipSpacing,
          );
          break;
        case TooltipPosition.left:
          preferredPosition = Offset(
            _targetRect!.left - tooltipSpacing,
            _targetRect!.center.dy,
          );
          break;
        case TooltipPosition.right:
          preferredPosition = Offset(
            _targetRect!.right + tooltipSpacing,
            _targetRect!.center.dy,
          );
          break;
      }
    }

    // Корректируем позицию, чтобы tooltip не выходил за границы экрана
    // Для горизонтального центрирования (учитываем safe area)
    if (bestPosition == TooltipPosition.top || bestPosition == TooltipPosition.bottom) {
      preferredPosition = Offset(
        preferredPosition.dx.clamp(
          padding + safeAreaLeft + estimatedTooltipWidth / 2,
          screenSize.width - padding - safeAreaRight - estimatedTooltipWidth / 2,
        ),
        preferredPosition.dy,
      );
    }
    
    // Для вертикального центрирования (учитываем safe area)
    if (bestPosition == TooltipPosition.left || bestPosition == TooltipPosition.right) {
      preferredPosition = Offset(
        preferredPosition.dx,
        preferredPosition.dy.clamp(
          padding + safeAreaTop + estimatedTooltipHeight / 2,
          screenSize.height - padding - safeAreaBottom - estimatedTooltipHeight / 2,
        ),
      );
    }
    
    // Сохраняем фактическую позицию для правильного центрирования
    _actualPosition = useBestPosition ? bestPosition : widget.position;
    
    // Получаем реальный размер tooltip или используем оценку
    final tooltipWidth = _tooltipSize?.width ?? estimatedTooltipWidth;
    final tooltipHeight = _tooltipSize?.height ?? estimatedTooltipHeight;
    
    // Вычисляем позицию с учетом реального размера tooltip
    // Для мобильных устройств используем более строгие ограничения
    double finalLeft;
    double finalTop;
    
    if (bestPosition == TooltipPosition.top || bestPosition == TooltipPosition.bottom) {
      // Горизонтальное центрирование относительно targetRect
      // Учитываем safe area для правильного позиционирования
      finalLeft = (preferredPosition.dx - tooltipWidth / 2).clamp(
        padding + safeAreaLeft, 
        screenSize.width - padding - safeAreaRight - tooltipWidth,
      );
      // Вертикальная позиция
      finalTop = _calculateTopPosition(tooltipHeight, screenSize);
    } else {
      // Вертикальное центрирование относительно targetRect
      finalTop = (preferredPosition.dy - tooltipHeight / 2).clamp(
        padding + safeAreaTop, 
        screenSize.height - padding - safeAreaBottom - tooltipHeight,
      );
      // Горизонтальная позиция
      if (bestPosition == TooltipPosition.left) {
        finalLeft = preferredPosition.dx - tooltipWidth - tooltipSpacing;
      } else {
        finalLeft = preferredPosition.dx + tooltipSpacing;
      }
      // Учитываем safe area для горизонтальных отступов
      finalLeft = finalLeft.clamp(
        padding + safeAreaLeft, 
        screenSize.width - padding - safeAreaRight - tooltipWidth,
      );
    }
    
    double verticalShift = 0.0;
    if (widget.title.contains('История сообщений')) {
      verticalShift = -40.0;
    } else if (widget.title.contains('Поле ввода') ||
        widget.title.contains('первое сообщение')) {
      verticalShift = -60.0;
    }

    final adjustedTop = (finalTop + verticalShift).clamp(
      padding + safeAreaTop,
      screenSize.height - padding - safeAreaBottom - tooltipHeight,
    );

    final finalPosition =
        Offset(finalLeft + tooltipWidth / 2, adjustedTop + tooltipHeight / 2);
    
    // Всегда обновляем позицию для плавного перемещения (AnimatedPositioned позаботится об анимации)
    setState(() {
      _tooltipPosition = finalPosition;
      _stableLeft = finalLeft;
      _stableTop = adjustedTop;
    });
  }
  
  double _calculateTopPosition(double tooltipHeight, Size screenSize) {
    if (_targetRect == null) return 0.0;
    
    final isMobile = screenSize.width < 600;
    final spacing = isMobile ? 8.0 : 12.0;
    final padding = isMobile ? 12.0 : 16.0;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final pos = _actualPosition ?? widget.position;
    
    // Для элементов в AppBar (выбор модели) учитываем AppBar высоту
    final isInAppBar = widget.title.contains('модел') || widget.title.contains('AI');
    final appBarHeight = isInAppBar ? 48.0 : 0.0; // Стандартная высота AppBar
    
    double top;
    if (pos == TooltipPosition.top) {
      top = _targetRect!.top - tooltipHeight - spacing;
      // Для элементов в AppBar добавляем дополнительный отступ
      if (isInAppBar) {
        top = _targetRect!.bottom + spacing; // Размещаем снизу от AppBar
      }
    } else if (pos == TooltipPosition.bottom) {
      top = _targetRect!.bottom + spacing;
      // Для элементов в AppBar размещаем ниже AppBar
      if (isInAppBar) {
        top = _targetRect!.bottom + spacing + 8; // Дополнительный отступ от AppBar
      }
    } else {
      // Для left/right позиций центрируем вертикально
      top = _targetRect!.center.dy - tooltipHeight / 2;
    }
    
    // Учитываем safe area для мобильных устройств
    // На мобильных устройствах более строгие ограничения
    final minTop = padding + safeAreaTop + (isInAppBar ? appBarHeight : 0);
    final maxTop = screenSize.height - padding - safeAreaBottom - tooltipHeight;
    
    // Если tooltip не помещается, выбираем лучшую позицию
    if (top < minTop) {
      // Не хватает места сверху - размещаем снизу
      if (pos == TooltipPosition.top && _targetRect!.bottom + spacing + tooltipHeight <= maxTop) {
        top = _targetRect!.bottom + spacing;
      } else {
        top = minTop;
      }
    } else if (top > maxTop) {
      // Не хватает места снизу - размещаем сверху
      if (pos == TooltipPosition.bottom && _targetRect!.top - spacing - tooltipHeight >= minTop) {
        top = _targetRect!.top - tooltipHeight - spacing;
      } else {
        top = maxTop;
      }
    }
    
    return top.clamp(minTop, maxTop);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: Stack(
        children: [
        // Затемнение с вырезом и волнами (от подсвеченного элемента).
        // AbsorbPointer блокирует клики по фону.
        AbsorbPointer(
          absorbing: true,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _targetRectAnimation,
              _pulseAnimation,
              _rippleAnimation,
            ]),
            builder: (context, child) {
              // Используем анимированный Rect для плавного перехода
              // Во время перехода анимация обеспечивает плавное движение затемнения вниз
              // Если анимация активна, используем её значение, иначе текущий Rect
              final animatedRect = _targetRectAnimation.value ?? _targetRect;
              if (animatedRect == null) {
                return const SizedBox.shrink();
              }
              
              // Определяем непрозрачность затемнения в зависимости от экрана
              // Для home и provider экранов делаем менее темным
              final isHomeOrProvider = widget.title.contains('Статус системы') || 
                                      widget.title.contains('Настройка провайдера') ||
                                      widget.title.contains('провайдера') ||
                                      widget.title.contains('Чат с AI') ||
                                      widget.title.contains('Статистика') ||
                                      widget.title.contains('График расходов') ||
                                      widget.title.contains('Настройки');
              final overlayAlpha = isHomeOrProvider ? 0.3 : 0.5; // Менее темное для home/provider
              
              // Всегда рисуем затемнение, чтобы покрыть весь экран во время перехода
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _OverlayPainter(
                    targetRect: animatedRect,
                    overlayColor: Colors.black.withValues(alpha: overlayAlpha),
                    highlightColor: scheme.primary.withValues(alpha: 0.3),
                    pulseScale: _pulseAnimation.value,
                    rippleProgress: _rippleAnimation.value,
                  ),
                  size: screenSize,
                ),
              );
            },
          ),
        ),

        // Прозрачный барьер, чтобы клики вне подсказки не проходили к экрану
        const ModalBarrier(
          color: Colors.transparent,
          dismissible: false,
        ),

        // Подсказка с плавным перемещением и появлением
        if (_tooltipPosition != null && _stableLeft >= 0 && _stableTop >= 0)
          AnimatedPositioned(
            // Синхронизируем длительность с анимацией затемнения для плавности
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic, // Та же кривая для синхронизации
            left: _stableLeft.clamp(0.0, screenSize.width),
            top: _stableTop.clamp(0.0, screenSize.height),
            child: AnimatedSwitcher(
              // Увеличена длительность для более плавного перехода
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.fastOutSlowIn,
              switchOutCurve: Curves.fastOutSlowIn,
              transitionBuilder: (child, animation) {
                // Плавное появление с легким масштабированием
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.fastOutSlowIn,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Material(
                // Используем currentStep для плавного обновления контента
                key: ValueKey('tooltip_${widget.currentStep}'),
                color: Colors.transparent,
                child: _buildTooltip(context, scheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 600;
        
        // Адаптивная ширина для мобильных с учетом safe area
        // Уменьшаем размер для компактности на маленьких экранах
        final safeAreaLeft = MediaQuery.of(context).padding.left;
        final safeAreaRight = MediaQuery.of(context).padding.right;
        final horizontalPadding = isMobile ? 16.0 : 20.0;
        final availableWidth = screenSize.width - safeAreaLeft - safeAreaRight - horizontalPadding * 2;
        final maxWidth = isMobile 
            ? availableWidth.clamp(260.0, 360.0)
            : 320.0;

        return Container(
          key: _tooltipKey,
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: isMobile ? 260.0 : 280.0,
          ),
          margin: EdgeInsets.only(
            left: isMobile ? 8.0 : 12.0,
            right: isMobile ? 8.0 : 12.0,
            top: isMobile ? 8.0 : 12.0,
            bottom: isMobile ? 8.0 : 12.0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14.0 : 18.0,
            vertical: isMobile ? 12.0 : 16.0,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Индикатор прогресса с анимацией
              if (widget.totalSteps > 1)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: widget.currentStep / widget.totalSteps,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: scheme.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.currentStep}/${widget.totalSteps}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Заголовок с плавным появлением
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Text(
                  widget.title,
                  key: ValueKey('title_${widget.currentStep}'),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              // Описание с плавным появлением
              if (widget.description != null) ...[
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(
                    widget.description!,
                    key: ValueKey('desc_${widget.currentStep}'),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Кнопки с дополнительным padding снизу для предотвращения перекрытия
              Padding(
                padding: EdgeInsets.only(
                  bottom: isMobile ? 8.0 : 12.0, // Дополнительный отступ снизу
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Скрываем кнопку "Пропустить" если обучение с одним шагом
                    if (widget.showSkip && widget.totalSteps > 1)
                      TextButton(
                        onPressed: widget.onSkip,
                        child: Text(
                          'Пропустить',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    if (widget.showSkip && widget.totalSteps > 1)
                      const SizedBox(width: 8),
                    FilledButton(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.currentStep < widget.totalSteps
                            ? 'Далее'
                            : 'Завершить',
                        style: const TextStyle(decoration: TextDecoration.none),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Кастомный Tween для плавного перехода Rect
class _RectTween extends Tween<Rect?> {
  _RectTween({required Rect begin, required Rect end})
      : super(begin: begin, end: end);

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return begin ?? end;
    
    return Rect.lerp(begin!, end!, t);
  }
}

/// Позиция подсказки относительно подсвеченного элемента
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
}

/// Custom painter для затемнения с вырезом, подсветкой и волнами
class _OverlayPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final Color highlightColor;
  final double pulseScale;
  final double rippleProgress;

  _OverlayPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.highlightColor,
    required this.pulseScale,
    required this.rippleProgress,
  });

  void _drawRipples(Canvas canvas, Offset center) {
    // Рисуем волны от центра (для подсвеченного элемента)
    final rippleCount = 3;
    for (int i = 0; i < rippleCount; i++) {
      final rippleOffset = (rippleProgress + i * 0.33) % 1.0;
      final radius = 20 + rippleOffset * 80;
      final alpha = (1.0 - rippleOffset) * 0.15;

      final ripplePaint = Paint()
        ..color = highlightColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(center, radius, ripplePaint);
    }
  }


  @override
  void paint(Canvas canvas, Size size) {
    final targetCenter = targetRect.center;

    // Рисуем волны от центра цели (круглые)
    _drawRipples(canvas, targetCenter);

    // Рисуем затемнение - всегда покрываем весь экран для плавного перехода
    final overlayPaint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Вырезаем область цели с плавным скруглением
    // Используем немного увеличенный радиус для более плавного визуального эффекта
    final inflatedRect = targetRect.inflate(8 * pulseScale);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          inflatedRect,
          const Radius.circular(14), // Увеличенный радиус для более плавного вида
        ),
      )
      ..fillType = PathFillType.evenOdd;

    // Используем BlendMode.clear для создания прозрачного выреза
    // Это обеспечивает плавное перемещение без мерцания
    canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.rippleProgress != rippleProgress;
  }
}

