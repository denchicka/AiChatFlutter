import 'package:flutter/material.dart';

import 'hover_tile.dart';
import 'small_switch.dart';

class ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? infoPressed;

  const ToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.infoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return HoverTile(
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (infoPressed != null)
            IconButton(
              tooltip: 'Инструкция',
              visualDensity: VisualDensity.compact,
              onPressed: infoPressed,
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          SmallSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
