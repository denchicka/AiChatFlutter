import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  IconData _icon(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.system => Icons.brightness_auto_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final mode = theme.mode;
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: 'Тема',
      icon: Icon(_icon(mode), color: scheme.onSurfaceVariant, size: 18),
      onPressed: () {
        // быстрый toggle Light <-> Dark (System не трогаем)
        final next =
            (mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
        context.read<ThemeProvider>().setMode(next);
      },
      onLongPress: () async {
        ThemeMode? selectedMode = mode;
        
        final picked = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(title: Text('Тема')),
                  RadioGroup<ThemeMode>(
                    groupValue: selectedMode,
                    onChanged: (value) {
                      setState(() {
                        selectedMode = value;
                      });
                      Navigator.pop(ctx, value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: const Text('Как в системе'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: const Text('Светлая'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: const Text('Тёмная'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );

        if (picked != null && context.mounted) {
          context.read<ThemeProvider>().setMode(picked);
        }
      },
    );
  }
}
