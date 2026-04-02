import 'package:flutter/material.dart';

class PodcastEmptyState extends StatelessWidget {
  const PodcastEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.padding = EdgeInsets.zero,
    this.titleStyle,
    this.subtitleStyle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style:
                  titleStyle ??
                  theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style:
                    subtitleStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
