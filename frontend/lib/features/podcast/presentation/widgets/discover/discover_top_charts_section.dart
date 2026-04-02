import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_category_chips.dart';

/// Top charts section header with category chips
class DiscoverTopChartsSection extends ConsumerWidget {
  const DiscoverTopChartsSection({
    super.key,
    required this.state,
    required this.onCategorySelected,
    this.isDense = false,
  });

  final PodcastDiscoverState state;
  final ValueChanged<String> onCategorySelected;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.w700);
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final countryName = _countryDisplayName(state.country, l10n);

    return Column(
      key: const Key('podcast_discover_top_charts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.podcast_discover_top_charts, style: titleStyle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.podcast_discover_trending_in(countryName),
                    key: const Key('podcast_discover_trending_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isDense ? 6 : 10),
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
