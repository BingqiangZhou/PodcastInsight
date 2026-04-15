import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.title, required this.children, super.key,
    this.cardMargin = EdgeInsets.zero,
    this.cardShape,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry cardMargin;

  /// Ignored (retained for API compatibility).
  final ShapeBorder? cardShape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: cardMargin,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
