import 'package:flutter/material.dart';

class HoverTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const HoverTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = destructive ? scheme.error : scheme.onSurface;
    final subColor = scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        hoverColor: scheme.primary.withValues(alpha: 0.06),
        highlightColor: scheme.primary.withValues(alpha: 0.08),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        fontSize: 13,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: TextStyle(color: subColor, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconTheme(
                data: IconThemeData(
                  color: destructive ? scheme.error : scheme.onSurfaceVariant,
                ),
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
