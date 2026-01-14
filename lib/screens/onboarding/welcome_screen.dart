import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';

/// Приветственный экран с вау-эффектом появления
/// 
/// Показывается только при первом запуске приложения
/// Использует современные анимации и эффекты для создания впечатления
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _particleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация появления (fade + scale)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Анимация текста (slide up)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Анимация частиц
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.linear,
      ),
    );

    // Запускаем анимации последовательно
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    _scaleController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.completeWelcome();
    
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final onboarding = context.watch<OnboardingProvider>();
    final isFirstLaunch = !onboarding.welcomeCompleted;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                    const Color(0xFF90CAF9),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Анимированные частицы на фоне
              AnimatedBuilder(
                animation: _particleAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ParticlePainter(
                      progress: _particleAnimation.value,
                      color: scheme.primary.withValues(alpha: 0.3),
                    ),
                    size: Size.infinite,
                  );
                },
              ),

              // Основной контент
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Иконка приложения с эффектом свечения
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  scheme.primary.withValues(alpha: 0.3),
                                  scheme.primary.withValues(alpha: 0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              size: 80,
                              color: scheme.primary,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Заголовок
                          SlideTransition(
                            position: _slideAnimation,
                            child: Text(
                              'Добро пожаловать!',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Подзаголовок
                          SlideTransition(
                            position: _slideAnimation,
                            child: Text(
                              'Представляем вам\nAI Chat Flutter',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Описание
                          SlideTransition(
                            position: _slideAnimation,
                            child: Text(
                              'Современный чат с искусственным интеллектом.\n'
                              'Быстрое обучение поможет вам начать работу.',
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 64),

                          // Кнопка "Начать"
                          SlideTransition(
                            position: _slideAnimation,
                            child: FilledButton(
                              onPressed: _onContinue,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Начать',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          // Кнопка "Пропустить" - показываем только при первом запуске
                          if (isFirstLaunch) ...[
                            const SizedBox(height: 16),
                            SlideTransition(
                              position: _slideAnimation,
                              child: TextButton(
                                onPressed: _onContinue,
                                child: Text(
                                  'Пропустить обучение',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кастомный painter для анимированных частиц на фоне
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final particleCount = 20;
    final random = math.Random(42); // Фиксированный seed для стабильности

    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 2 + random.nextDouble() * 3;
      final offset = (progress + random.nextDouble() * 0.5) % 1.0;

      final alpha = (math.sin(offset * math.pi * 2) * 0.5 + 0.5) * 0.6;
      final currentPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, currentPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
