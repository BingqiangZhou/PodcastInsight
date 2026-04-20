import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/linear_section_header.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_category_chips.dart';

/// Top charts section header with category chips
class DiscoverTopChartsSection extends ConsumerWidget {
  const DiscoverTopChartsSection({
    required this.state, required this.onCategorySelected, super.key,
    this.isDense = false,
  });

  final PodcastDiscoverState state;
  final ValueChanged<String> onCategorySelected;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final countryName = _countryDisplayName(state.country, l10n);

    return Column(
      key: const Key('podcast_discover_top_charts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearSectionHeader.label(
          l10n.podcast_discover_top_charts,
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xs,
            vertical: isDense ? context.spacing.xs : context.spacing.smMd,
          ),
          trailing: Padding(
            padding: EdgeInsets.only(right: context.spacing.md),
            child: Text(
              l10n.podcast_discover_trending_in(countryName),
              key: const Key('podcast_discover_trending_label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(height: isDense ? context.spacing.xs : context.spacing.smMd),
        DiscoverCategoryChips(
          state: state,
          onCategorySelected: onCategorySelected,
        ),
      ],
    );
  }

  String _countryDisplayName(PodcastCountry country, AppLocalizations l10n) {
    final key = country.localizationKey;
    return switch (key) {
      'podcast_country_china' => l10n.podcast_country_china,
      'podcast_country_usa' => l10n.podcast_country_usa,
      'podcast_country_japan' => l10n.podcast_country_japan,
      'podcast_country_uk' => l10n.podcast_country_uk,
      'podcast_country_germany' => l10n.podcast_country_germany,
      'podcast_country_france' => l10n.podcast_country_france,
      'podcast_country_canada' => l10n.podcast_country_canada,
      'podcast_country_australia' => l10n.podcast_country_australia,
      'podcast_country_korea' => l10n.podcast_country_korea,
      'podcast_country_taiwan' => l10n.podcast_country_taiwan,
      'podcast_country_hong_kong' => l10n.podcast_country_hong_kong,
      'podcast_country_india' => l10n.podcast_country_india,
      'podcast_country_brazil' => l10n.podcast_country_brazil,
      'podcast_country_mexico' => l10n.podcast_country_mexico,
      'podcast_country_spain' => l10n.podcast_country_spain,
      'podcast_country_italy' => l10n.podcast_country_italy,
      _ => country.code.toUpperCase(),
    };
  }
}
