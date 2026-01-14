import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import 'onboarding_overlay.dart';

/// Обертка для добавления onboarding к любому экрану
/// 
/// Использование:
/// ```dart
/// ScreenOnboardingWrapper(
///   screenName: 'settings',
///   child: YourScreen(),
///   steps: [
///     OnboardingStep(
///       key: _someKey,
///       title: 'Заголовок',
///       description: 'Описание',
///       position: TooltipPosition.bottom,
///     ),
///   ],
/// )
/// ```
class ScreenOnboardingWrapper extends StatefulWidget {
  final String screenName;
  final Widget child;
  final List<OnboardingStep> steps;

  const ScreenOnboardingWrapper({
    super.key,
    required this.screenName,
    required this.child,
    required this.steps,
  });

  @override
  State<ScreenOnboardingWrapper> createState() => _ScreenOnboardingWrapperState();
}

class _ScreenOnboardingWrapperState extends State<ScreenOnboardingWrapper> {
  int _currentStep = 0;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onboarding = context.read<OnboardingProvider>();
      if (onboarding.shouldShowOnboarding(widget.screenName)) {
        setState(() {
          _showOnboarding = true;
        });
      }
    });
  }

  void _onNext() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _complete();
    }
  }

  void _onSkip() {
    _complete();
  }

  Future<void> _complete() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.completeScreen(widget.screenName);
    
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOnboarding || _currentStep >= widget.steps.length) {
      return widget.child;
    }

    final step = widget.steps[_currentStep];

    return Stack(
      children: [
        widget.child,
        OnboardingOverlay(
          targetKey: step.key,
          title: step.title,
          description: step.description,
          position: step.position,
          currentStep: _currentStep + 1,
          totalSteps: widget.steps.length,
          onNext: _onNext,
          onSkip: _onSkip,
        ),
      ],
    );
  }
}

/// Шаг обучения для экрана
class OnboardingStep {
  final GlobalKey key;
  final String title;
  final String description;
  final TooltipPosition position;

  const OnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.position,
  });
}
