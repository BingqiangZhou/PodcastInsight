import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/download_button.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

/// Configuration for what to display in a [BaseEpisodeCard].
class EpisodeCardConfig {
  const EpisodeCardConfig({
    this.showImage = true,
    this.imageUrl,
    this.imageSize = 62.0,
    this.imageIconSize = 24.0,
    this.imageBorderRadius = 8.0,
    this.titleMaxLines = 2,
    this.subtitleMaxLines = 1,
    this.showSubscriptionBadge = false,
    this.subscriptionBadgeText,
    this.showDate = false,
    this.date,
    this.showDuration = false,
    this.formattedDuration,
    this.showDescription = false,
    this.description,
    this.descriptionMaxLines = 4,
    this.dense = false,
    this.cardMargin,
    this.cardPadding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.cornerRadius = 12.0,
    this.showPlayButton = true,
    this.showQueueButton = false,
    this.isAddingToQueue = false,
    this.showSubscribeAction = false,
    this.isSubscribed = false,
    this.isSubscribing = false,
    this.showDownloadButton = false,
    this.episodeId,
    this.audioUrl,
    this.episodeTitle,
    this.subscriptionTitle,
    this.subscriptionImageUrl,
    this.subscriptionId,
    this.audioDuration,
    this.publishedAt,
    this.heroTag,
    this.identityColor,
    this.showIdentityColorBar = false,
  });

  final bool showImage;
  final String? imageUrl;
  final double imageSize;
  final double imageIconSize;
  final double imageBorderRadius;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final bool showSubscriptionBadge;
  final String? subscriptionBadgeText;
  final bool showDate;
  final DateTime? date;
  final bool showDuration;
  final String? formattedDuration;
  final bool showDescription;
  final String? description;
  final int descriptionMaxLines;
  final bool dense;
  final EdgeInsetsGeometry? cardMargin;
  final EdgeInsetsGeometry cardPadding;
  final double cornerRadius;
  final bool showPlayButton;
  final bool showQueueButton;
  final bool isAddingToQueue;
  final bool showSubscribeAction;
  final bool isSubscribed;
  final bool isSubscribing;
  final bool showDownloadButton;
  final int? episodeId;
  final String? audioUrl;
  final String? episodeTitle;
  final String? subscriptionTitle;
  final String? subscriptionImageUrl;
  final int? subscriptionId;
  final int? audioDuration;
  final DateTime? publishedAt;

  /// Optional Hero tag for shared element transitions to detail pages.
  /// When provided, the image will be wrapped in a Hero widget.
  final String? heroTag;

  /// Optional identity color for the left accent bar (3px wide).
  /// When provided, a 3px vertical bar is shown on the left edge.
  final Color? identityColor;

  /// Whether to show the identity color bar on the left edge.
  /// Requires [identityColor] to be set.
  final bool showIdentityColorBar;
}

/// A reusable base episode card with configurable layout.
///
/// Provides the common structure: `Card > InkWell > Column[HeaderRow, Description, MetaActionRow]`
/// where HeaderRow = `[Image?, Title, ActionIcon]`.
///
/// Each specific card variant (feed, simplified, search result, etc.) configures
/// a [BaseEpisodeCard] instead of reimplementing the layout.
class BaseEpisodeCard extends StatelessWidget {
  const BaseEpisodeCard({
    super.key,
    required this.config,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitle2,
    this.trailingWidget,
    this.onPlay,
    this.onAddToQueue,
    this.onSubscribe,
    this.additionalMetadata,
  });

  final EpisodeCardConfig config;
  final String title;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? subtitle2;
  final Widget? trailingWidget;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onSubscribe;

  /// Additional metadata widgets to display between date/duration and action buttons.
  final List<Widget>? additionalMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cardContent = SurfaceCard(
      borderRadius: config.cornerRadius,
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(config.cornerRadius),
            child: Padding(
              padding: config.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(context, theme),
                  if (config.showDescription &&
                      config.description != null &&
                      config.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Flexible(child: _buildDescription(context, theme)),
                    const SizedBox(height: 4),
                  ] else if (config.showDescription) ...[
                    const SizedBox(height: 4),
                  ],
                  if (_hasMetaOrActions)
                    _buildMetaActionRow(context, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: config.cardMargin ?? EdgeInsets.zero,
      child: config.showIdentityColorBar && config.identityColor != null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: config.identityColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(config.cornerRadius),
                      bottomLeft: Radius.circular(config.cornerRadius),
                    ),
                  ),
                ),
                Expanded(child: cardContent),
              ],
            )
          : cardContent,
    );
  }

  bool get _hasMetaOrActions =>
      config.showSubscriptionBadge ||
      config.showDate ||
      config.showDuration ||
      config.showQueueButton ||
      config.showDownloadButton ||
      config.showSubscribeAction ||
      (additionalMetadata != null && additionalMetadata!.isNotEmpty);

  Widget _buildHeaderRow(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final titleStyle = (config.dense
            ? theme.textTheme.titleSmall
            : theme.textTheme.titleMedium)
        ?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.showImage && config.imageUrl != null) ...[
          _buildImage(context, theme),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: titleStyle,
                maxLines: config.titleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: config.subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (subtitle2 != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle2!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: config.subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (trailingWidget != null)
          trailingWidget!
        else if (config.showPlayButton)
          _buildPlayButton(context, theme),
      ],
    );
  }

  Widget _buildImage(BuildContext context, ThemeData theme) {
    final size = config.imageSize;
    final image = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(config.imageBorderRadius),
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(config.imageBorderRadius),
          child: PodcastImageWidget(
            imageUrl: config.imageUrl!,
            width: size,
            height: size,
            iconSize: config.imageIconSize,
            iconColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );

    if (config.heroTag != null) {
      return Hero(tag: config.heroTag!, child: image);
    }
    return image;
  }

  Widget _buildPlayButton(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.podcast_play,
      onPressed: onPlay,
      icon: Icon(
        config.dense
            ? Icons.play_circle_outline
            : Icons.play_circle_outline,
        size: config.dense ? 22 : 26,
      ),
      iconSize: config.dense ? 22 : 26,
      color: theme.colorScheme.onSurfaceVariant,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildDescription(BuildContext context, ThemeData theme) {
    final isMobile =
        MediaQuery.sizeOf(context).width < 600;
    return Text(
      config.description!,
      style: (isMobile
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodySmall)
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      maxLines: config.dense ? 2 : config.descriptionMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetaActionRow(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (config.showSubscriptionBadge)
                    _buildSubscriptionBadge(theme),
                  if (config.showSubscriptionBadge &&
                      (config.showDate || config.showDuration))
                    const SizedBox(width: 8),
                  if (config.showDate && config.date != null)
                    EpisodeCardUtils.buildDateMetadata(
                      date: config.date!,
                      theme: theme,
                      spacing: config.dense ? 3 : 2,
                    ),
                  if (config.showDate && config.showDuration)
                    const SizedBox(width: 8),
                  if (config.showDuration &&
                      config.formattedDuration != null)
                    EpisodeCardUtils.buildDurationMetadata(
                      formattedDuration: config.formattedDuration!,
                      theme: theme,
                      spacing: config.dense ? 3 : 2,
                    ),
                  if (additionalMetadata != null)
                    ...additionalMetadata!,
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (config.showDownloadButton &&
            config.episodeId != null &&
            config.audioUrl != null &&
            config.audioUrl!.isNotEmpty) ...[
          DownloadButton(
            episodeId: config.episodeId!,
            audioUrl: config.audioUrl!,
            size: config.dense ? 16 : 18,
            title: config.episodeTitle,
            subscriptionTitle: config.subscriptionTitle,
            imageUrl: config.imageUrl,
            subscriptionImageUrl: config.subscriptionImageUrl,
            subscriptionId: config.subscriptionId,
            audioDuration: config.audioDuration,
            publishedAt: config.publishedAt,
          ),
          const SizedBox(width: 4),
        ],
        if (config.showQueueButton)
          IconButton(
            tooltip: config.isAddingToQueue
                ? l10n.podcast_adding
                : l10n.podcast_add_to_queue,
            onPressed: config.isAddingToQueue ? null : onAddToQueue,
            style: EpisodeCardUtils.compactIconButtonStyle(theme),
            icon: config.isAddingToQueue
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.playlist_add, size: 18),
          ),
        if (config.showSubscribeAction) ...[
          const SizedBox(width: 6),
          _buildSubscribeAction(context, theme),
        ],
      ],
    );
  }

  Widget _buildSubscriptionBadge(ThemeData theme) {
    final badgeBackgroundColor = theme.colorScheme.onSurfaceVariant;
    final badgeTextColor = theme.colorScheme.surface;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: config.dense ? 140 : 170),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: config.dense ? 8 : 10,
          vertical: config.dense ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor,
          borderRadius: BorderRadius.circular(config.dense ? 10 : 12),
        ),
        child: Text(
          config.subscriptionBadgeText ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (config.dense
                  ? AppTheme.navLabel(badgeTextColor, weight: FontWeight.w700)
                  : AppTheme.metaSmall(badgeTextColor).copyWith(
                      fontWeight: FontWeight.w700,
                    )),
        ),
      ),
    );
  }

  Widget _buildSubscribeAction(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    if (config.isSubscribed) {
      return Tooltip(
        message: l10n.podcast_subscribed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
      );
    }

    if (config.isSubscribing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Tooltip(
      message: l10n.podcast_subscribe,
      child: IconButton(
        onPressed: onSubscribe,
        icon: const Icon(Icons.add_circle_outline),
        iconSize: 24,
        color: theme.colorScheme.onSurfaceVariant,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
