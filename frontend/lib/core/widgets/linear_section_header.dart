import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';

/// A Linear-style section header with title and optional trailing widget.
///
/// Features:
/// - 48px display title (adjustable)
/// - Optional subtitle with reduced opacity
/// - Optional trailing widget (e.g., button, icon)
/// - Consistent vertical spacing
///
/// Use [LinearSectionHeader.label] for the small uppercase label variant
/// (11px, letter-spacing 1px, muted color — the Linear design pattern).
class LinearSectionHeader extends StatelessWidget {
  const LinearSectionHeader({
    required this.title, super.key,
    this.subtitle,
    this.trailing,
    this.titleSize = 48,
    this.padding,
  }) : _isLabel = false;

  /// Small uppercase label variant — the Linear design pattern.
  ///
  /// - Font size: 11px
  /// - Text transform: uppercase
  /// - Letter spacing: 1px
  /// - Color: onSurfaceMuted
  /// - Font weight: w600
  const LinearSectionHeader.label(
    this.title, {
    super.key,
    this.trailing,
    this.padding,
  })  : subtitle = null,
        titleSize = 48,
        _isLabel = true;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleSize;
  final EdgeInsetsGeometry? padding;
  final bool _isLabel;

  @override
  Widget build(BuildContext context) {
    if (_isLabel) {
      return _buildLabel(context);
    }
    return _buildDisplay(context);
  }

  Widget _buildLabel(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.symmetric(
      horizontal: context.spacing.mdLg,
      vertical: context.spacing.smMd,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.darkOnSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTheme.metaSmall(mutedColor).copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _buildDisplay(BuildContext context) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final effectivePadding = padding ?? EdgeInsets.symmetric(
      horizontal: context.spacing.mdLg,
      vertical: isMobile ? context.spacing.smMd : context.spacing.md,
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: effectivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: context.spacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A smaller Linear-style section header for subsections.
///
/// Features:
/// - 24px title (adjustable)
/// - Optional leading icon
/// - Optional trailing widget
/// - Compact padding
class LinearSubsectionHeader extends StatelessWidget {
  const LinearSubsectionHeader({
    required this.title, super.key,
    this.leading,
    this.trailing,
    this.titleSize = 24,
    this.padding,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double titleSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.symmetric(
      horizontal: context.spacing.mdLg,
      vertical: context.spacing.smMd,
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: context.spacing.smMd),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
