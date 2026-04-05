import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.cardMargin = EdgeInsets.zero,
    this.cardShape,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry cardMargin;

  /// Ignored when using GlassContainer (retained for API compatibility).
  final ShapeBorder? cardShape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
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
          child: GlassContainer(
            tier: GlassTier.light,
            borderRadius: 12,
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
