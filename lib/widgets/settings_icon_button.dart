import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsIconButton extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? padding;
  final bool useGo; // если хотите replace-переход; обычно push
  const SettingsIconButton({
    super.key,
    this.size = 20,
    this.padding,
    this.useGo = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Настройки',
      padding: padding,
      icon: Icon(Icons.settings, size: size),
      onPressed: () =>
          useGo ? context.go('/settings') : context.push('/settings'),
    );
  }
}
