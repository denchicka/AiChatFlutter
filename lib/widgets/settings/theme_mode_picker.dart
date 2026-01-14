import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тема приложения',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Система'),
                  icon: Icon(Icons.settings_suggest_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Светлая'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Тёмная'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeProvider.mode},
              onSelectionChanged: (s) => themeProvider.setMode(s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Смена темы применяется сразу.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
