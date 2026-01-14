import 'package:flutter/material.dart';
import 'model_sort.dart';

class ModelSortControls extends StatelessWidget {
  final ModelSortKey sortKey;
  final ModelSortDir sortDir;
  final void Function(ModelSortKey key) onSortPressed;

  const ModelSortControls({
    super.key,
    required this.sortKey,
    required this.sortDir,
    required this.onSortPressed,
  });

  String _label(ModelSortKey k) => switch (k) {
        ModelSortKey.cost => 'Стоимость',
        ModelSortKey.name => 'Алфавит',
        ModelSortKey.context => 'Контекст',
      };

  IconData _icon(bool active) {
    if (!active) return Icons.unfold_more;
    return sortDir == ModelSortDir.desc
        ? Icons.arrow_downward
        : Icons.arrow_upward;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip(ModelSortKey k) {
      final active = k == sortKey;

      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSortPressed(k),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon(active),
                size: 14,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _label(k),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(ModelSortKey.cost),
          chip(ModelSortKey.name),
          chip(ModelSortKey.context),
        ],
      ),
    );
  }
}
