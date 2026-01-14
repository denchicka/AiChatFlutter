import 'dart:math' as math;
import 'package:flutter/material.dart';

class TypingDots extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final double lift; // амплитуда "прыжка"
  final Duration period;

  /// Если true — рисуем "пилюлю" с рамкой.
  /// Если false — только точки (когда внешний bubble уже рисует фон/радиус).
  final bool decorated;

  const TypingDots({
    super.key,
    this.dotSize = 6,
    this.spacing = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.lift = 5,
    this.period = const Duration(milliseconds: 900),
    this.decorated = true,
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _phase(int i) => (_c.value + i * 0.18) % 1.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        Widget dot(int i) {
          final t = _phase(i);
          final wave = math.sin(t * math.pi * 2); // -1..1
          final dy = -wave * widget.lift;
          final scale = 0.78 + 0.22 * (0.5 + 0.5 * wave);
          final opacity = 0.35 + 0.65 * scale;

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(0),
            SizedBox(width: widget.spacing),
            dot(1),
            SizedBox(width: widget.spacing),
            dot(2),
          ],
        );

        if (!widget.decorated) return row;

        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: row,
        );
      },
    );
  }
}
