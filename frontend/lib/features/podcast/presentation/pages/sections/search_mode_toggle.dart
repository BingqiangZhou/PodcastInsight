import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;

/// Toggle between episodes and podcasts search modes.
///
/// Uses a segmented-pill style with a filled background on the selected tab,
/// similar to [HeaderCapsuleActionButton] styling for visual consistency.
class SearchModeToggle extends StatelessWidget {
  const SearchModeToggle({
    required this.searchMode,
    required this.isDense,
    required this.onTabSelected,
    super.key,
  });

  final search.PodcastSearchMode searchMode;
  final bool isDense;
  final ValueChanged<search.PodcastSearchMode> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final toggleHeight = isDense ? 32.0 : 34.0;

    return Container(
      key: const Key('podcast_discover_tab_selector'),
      height: toggleHeight,
      padding: EdgeInsets.all(context.spacing.xxs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(toggleHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabPill(
            key: const Key('podcast_discover_tab_episodes'),
            label: l10n.podcast_episodes,
            icon: Icons.headphones_outlined,
            selected: searchMode == search.PodcastSearchMode.episodes,
            isDense: isDense,
            height: toggleHeight - 4,
            onTap: () => onTabSelected(search.PodcastSearchMode.episodes),
          ),
          SizedBox(width: context.spacing.xxs),
          _TabPill(
            key: const Key('podcast_discover_tab_podcasts'),
            label: l10n.podcast_title,
            icon: Icons.podcasts,
            selected: searchMode == search.PodcastSearchMode.podcasts,
            isDense: isDense,
            height: toggleHeight - 4,
            onTap: () => onTabSelected(search.PodcastSearchMode.podcasts),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDense,
    required this.height,
    required this.onTap,
  });

  @override
  final Key key;
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDense;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final backgroundColor = selected
        ? scheme.surfaceContainerLow
        : Colors.transparent;
    final foregroundColor = selected
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: foregroundColor,
    );

    return AnimatedContainer(
      duration: AppDurations.transitionFast,
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: foregroundColor),
                SizedBox(width: context.spacing.xs),
                Text(label, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
