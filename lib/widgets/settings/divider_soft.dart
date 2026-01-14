import 'package:flutter/material.dart';

class DividerSoft extends StatelessWidget {
  const DividerSoft({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
