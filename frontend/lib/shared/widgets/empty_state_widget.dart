import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

/// Generic empty state widget with icon, title, and optional subtitle.
///
/// Can be used across any feature to display an empty/content-unavailable state
/// with consistent styling.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon, required this.title, super.key,
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
            SizedBox(height: context.spacing.lg),
            Text(
              title,
              style:
                  titleStyle ??
                  theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: context.spacing.sm),
              Text(
                subtitle!,
                style:
                    subtitleStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
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
