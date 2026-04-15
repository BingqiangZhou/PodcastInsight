import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/font_combination.dart';

/// Safely resolve a Google Font, falling back to a plain TextStyle on failure.
TextStyle tryGetFont(String fontFamily, TextStyle textStyle) {
  try {
    return GoogleFonts.getFont(fontFamily, textStyle: textStyle);
  } on Object {
    return textStyle.copyWith(fontFamily: fontFamily);
  }
}

/// A preview card that renders a typography specimen for a font combination.
///
/// Shows heading, body, secondary, caption, and CJK text samples using
/// the given [combo]'s heading and body fonts.
class FontComboCard extends StatelessWidget {
  const FontComboCard({required this.combo, super.key, this.isSelected = false});

  final FontCombination combo;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);

    final child = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display heading
              Text(
                'Stella',
                style: tryGetFont(
                  combo.headingFontFamily,
                  TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -1.5,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Headline
              Text(
                'Your AI Assistant',
                style: tryGetFont(
                  combo.headingFontFamily,
                  TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Body text
              Text(
                'Body text for reading content with comfortable line height. '
                'This demonstrates how the font performs in paragraphs.',
                style: tryGetFont(
                  combo.bodyFontFamily,
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.65,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Secondary text
              Text(
                'Secondary text at 14px for descriptions and metadata.',
                style: tryGetFont(
                  combo.bodyFontFamily,
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Caption
              Text(
                'Caption text at 13px for timestamps',
                style: tryGetFont(
                  combo.bodyFontFamily,
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // CJK text
              Text(
                '你好世界 · 个人智能助手 · 播客转录',
                style: tryGetFont(
                  combo.bodyFontFamily,
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: scheme.onSurface,
                    fontFamilyFallback: const [
                      'Noto Sans SC',
                      'PingFang SC',
                      'Microsoft YaHei',
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isSelected)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.xsRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (isSelected) {
      // Selected state: show primary-colored border
      return Container(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(extension.cardRadius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: scheme.primary, width: 2),
            ),
            borderRadius: BorderRadius.circular(extension.cardRadius),
          ),
          child: child,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(extension.cardRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: child,
    );
  }
}
