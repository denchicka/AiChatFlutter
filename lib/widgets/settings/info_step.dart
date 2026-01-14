import 'package:flutter/material.dart';

class InfoStep extends StatelessWidget {
  final int index;
  final String text;

  const InfoStep({super.key, required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: scheme.primary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
