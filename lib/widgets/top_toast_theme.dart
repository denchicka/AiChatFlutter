import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'top_toast_types.dart';

class TopToastTheme extends ThemeExtension<TopToastTheme> {
  final double radius;
  final double elevation;
  final EdgeInsets padding;
  final Duration animationIn;
  final Duration animationOut;

  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;

  final Color successBg;
  final Color successFg;
  final Color successBorder;

  final Color errorBg;
  final Color errorFg;
  final Color errorBorder;

  const TopToastTheme({
    required this.radius,
    required this.elevation,
    required this.padding,
    required this.animationIn,
    required this.animationOut,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.successBg,
    required this.successFg,
    required this.successBorder,
    required this.errorBg,
    required this.errorFg,
    required this.errorBorder,
  });

  factory TopToastTheme.fromScheme(ColorScheme scheme) {
    Color borderOf(Color c) => Color.alphaBlend(
          scheme.outlineVariant.withValues(alpha: 0.55),
          c,
        );
    final green = const Color(0xFF34C759);
    final base = scheme.surfaceContainerHighest;

    final successBg = Color.alphaBlend(
      green.withValues(
          alpha: scheme.brightness == Brightness.dark ? 0.22 : 0.16),
      base,
    );
    return TopToastTheme(
      radius: 16,
      elevation: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      animationIn: const Duration(milliseconds: 260),
      animationOut: const Duration(milliseconds: 200),
      infoBg: scheme.surfaceContainerHighest,
      infoFg: scheme.onSurface,
      infoBorder: borderOf(scheme.surfaceContainerHighest),
      successBg: successBg,
      successFg: scheme.onSurface,
      successBorder: borderOf(successBg),
      errorBg: scheme.errorContainer,
      errorFg: scheme.onErrorContainer,
      errorBorder: borderOf(scheme.errorContainer),
    );
  }

  ({Color bg, Color fg, Color border}) resolve(TopToastType type) {
    return switch (type) {
      TopToastType.info => (bg: infoBg, fg: infoFg, border: infoBorder),
      TopToastType.success => (
          bg: successBg,
          fg: successFg,
          border: successBorder,
        ),
      TopToastType.error => (bg: errorBg, fg: errorFg, border: errorBorder),
    };
  }

  @override
  TopToastTheme copyWith({
    double? radius,
    double? elevation,
    EdgeInsets? padding,
    Duration? animationIn,
    Duration? animationOut,
    Color? infoBg,
    Color? infoFg,
    Color? infoBorder,
    Color? successBg,
    Color? successFg,
    Color? successBorder,
    Color? errorBg,
    Color? errorFg,
    Color? errorBorder,
  }) {
    return TopToastTheme(
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      animationIn: animationIn ?? this.animationIn,
      animationOut: animationOut ?? this.animationOut,
      infoBg: infoBg ?? this.infoBg,
      infoFg: infoFg ?? this.infoFg,
      infoBorder: infoBorder ?? this.infoBorder,
      successBg: successBg ?? this.successBg,
      successFg: successFg ?? this.successFg,
      successBorder: successBorder ?? this.successBorder,
      errorBg: errorBg ?? this.errorBg,
      errorFg: errorFg ?? this.errorFg,
      errorBorder: errorBorder ?? this.errorBorder,
    );
  }

  @override
  TopToastTheme lerp(ThemeExtension<TopToastTheme>? other, double t) {
    if (other is! TopToastTheme) return this;

    return TopToastTheme(
      radius: lerpDouble(radius, other.radius, t) ?? radius,
      elevation: lerpDouble(elevation, other.elevation, t) ?? elevation,
      padding: EdgeInsets.lerp(padding, other.padding, t) ?? padding,
      animationIn: t < 0.5 ? animationIn : other.animationIn,
      animationOut: t < 0.5 ? animationOut : other.animationOut,
      infoBg: Color.lerp(infoBg, other.infoBg, t) ?? infoBg,
      infoFg: Color.lerp(infoFg, other.infoFg, t) ?? infoFg,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t) ?? infoBorder,
      successBg: Color.lerp(successBg, other.successBg, t) ?? successBg,
      successFg: Color.lerp(successFg, other.successFg, t) ?? successFg,
      successBorder:
          Color.lerp(successBorder, other.successBorder, t) ?? successBorder,
      errorBg: Color.lerp(errorBg, other.errorBg, t) ?? errorBg,
      errorFg: Color.lerp(errorFg, other.errorFg, t) ?? errorFg,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t) ?? errorBorder,
    );
  }
}
