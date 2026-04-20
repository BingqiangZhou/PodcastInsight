import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';

/// Horizontal scrollable category chips for discover page
class DiscoverCategoryChips extends StatelessWidget {
  const DiscoverCategoryChips({
    required this.state, required this.onCategorySelected, super.key,
  });

  final PodcastDiscoverState state;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = state.categories;
    final theme = Theme.of(context);
    final selected = state.selectedCategory;

    final chipItems = <String>[
      '__all__',
      ...categories,
    ];
    final keyOccurrences = <String, int>{};

    return SingleChildScrollView(
      key: const Key('podcast_discover_category_chips'),
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs + context.spacing.xs,
      ),
      child: Row(
        children: [
          for (var index = 0; index < chipItems.length; index++) ...[
            () {
              final rawValue = chipItems[index];
              final baseKey = _normalizeCategoryKey(rawValue);
              final count = (keyOccurrences[baseKey] ?? 0) + 1;
              keyOccurrences[baseKey] = count;
              final uniqueKey = count == 1 ? baseKey : '${baseKey}_$count';

              return RepaintBoundary(
                key: ValueKey('category_chip_$uniqueKey'),
                child: _CategoryChip(
                  theme: theme,
                  label: rawValue == '__all__'
                      ? l10n.podcast_filter_all
                      : rawValue,
                  selected: rawValue == '__all__'
                      ? selected == '__all__'
                      : selected.toLowerCase() == rawValue.toLowerCase(),
                  onSelected: (_) => onCategorySelected(rawValue),
                  keyValue: uniqueKey,
                ),
              );
            }(),
            if (index != chipItems.length - 1) SizedBox(width: context.spacing.sm),
          ],
        ],
      ),
    );
  }

  String _normalizeCategoryKey(String value) {
    final normalized = value.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]+'),
      '_',
    );
    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'category' : trimmed;
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.keyValue,
  });

  final ThemeData theme;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    final selectedBackgroundColor = theme.colorScheme.primary;
    final selectedLabelColor = theme.colorScheme.surface;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.05 : 1.0),
      duration: AppDurations.scaleFast,
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: ChoiceChip(
        key: Key(
          'podcast_discover_category_chip_${_normalizeCategoryKey(keyValue)}',
        ),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        side: selected
            ? BorderSide(color: selectedBackgroundColor)
            : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: selected
              ? selectedLabelColor
              : theme.colorScheme.onSurfaceVariant,
        ),
        selectedColor: selectedBackgroundColor,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.sm),
      ),
    );
  }

  String _normalizeCategoryKey(String value) {
    final normalized = value.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]+'),
      '_',
    );
    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'category' : trimmed;
  }
}
