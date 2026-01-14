import 'package:flutter/material.dart';

enum CheckState { idle, running, ok, error }

class StatusLine extends StatelessWidget {
  final CheckState state;
  final String? text;

  const StatusLine({super.key, required this.state, required this.text});

  @override
  Widget build(BuildContext context) {
    if (state == CheckState.idle && (text == null || text!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (state) {
      case CheckState.running:
        icon = Icons.hourglass_top;
        color = scheme.onSurfaceVariant;
        break;
      case CheckState.ok:
        icon = Icons.check_circle_outline;
        color = scheme.tertiary;
        break;
      case CheckState.error:
        icon = Icons.error_outline;
        color = scheme.error;
        break;
      case CheckState.idle:
        icon = Icons.info_outline;
        color = scheme.onSurfaceVariant;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text ?? '',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
