import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import 'onboarding_overlay.dart';

/// Упрощенный onboarding для экранов с одним шагом
/// 
/// Использование:
/// ```dart
/// SimpleScreenOnboarding(
///   screenName: 'settings',
///   targetKey: _contentKey,
///   title: 'Настройки',
///   description: 'Описание...',
///   child: YourScreen(),
/// )
/// ```
class SimpleScreenOnboarding extends StatefulWidget {
  final String screenName;
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TooltipPosition position;
  final Widget child;

  const SimpleScreenOnboarding({
    super.key,
    required this.screenName,
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.top,
    required this.child,
  });

  @override
  State<SimpleScreenOnboarding> createState() => _SimpleScreenOnboardingState();
}

class _SimpleScreenOnboardingState extends State<SimpleScreenOnboarding> {
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
    _complete();
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
    return Stack(
      children: [
        widget.child,
        if (_showOnboarding)
          OnboardingOverlay(
            targetKey: widget.targetKey,
            title: widget.title,
            description: widget.description,
            position: widget.position,
            currentStep: 1,
            totalSteps: 1,
            onNext: _onNext,
            onSkip: _onSkip,
          ),
      ],
    );
  }
}
