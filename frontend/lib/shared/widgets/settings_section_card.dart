import 'package:flutter/material.dart';

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
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Card(
          margin: cardMargin,
          shape: cardShape,
          child: Column(children: children),
        ),
      ],
    );
  }
}
