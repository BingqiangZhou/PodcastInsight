import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
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
    this.cardPadding,
    this.cornerRadius = 12.0,
    this.showPlayButton = true,
    this.showQueueButton = false,
    this.isAddingToQueue = false,
    this.showSubscribeAction = false,
    this.isSubscribed = false,
    this.isSubscribing = false,
    this.showDownloadButton = false,
    this.downloadButtonSize,
    this.downloadQueueButtonSpacing,
    this.metadataFontSize,
    this.queueButtonSize,
    this.queueButtonIconSize,
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
    this.identityGradientColors,
    this.useGradientIdentityBar = false,
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
  final EdgeInsetsGeometry? cardPadding;
  final double cornerRadius;
  final bool showPlayButton;
  final bool showQueueButton;
  final bool isAddingToQueue;
  final bool showSubscribeAction;
  final bool isSubscribed;
  final bool isSubscribing;
  final bool showDownloadButton;
  final double? downloadButtonSize;
  final double? downloadQueueButtonSpacing;
  final double? metadataFontSize;
  final double? queueButtonSize;
  final double? queueButtonIconSize;
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

  /// Optional gradient colors for the left accent bar.
  /// When provided, a gradient vertical bar is shown on the left edge.
  final List<Color>? identityGradientColors;

  /// Whether to use gradient for the identity color bar.
  final bool useGradientIdentityBar;
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
    required this.config,
    required this.title,
    required this.onTap,
    super.key,
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
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final hasDescription =
        config.showDescription &&
        config.description != null &&
        config.description!.isNotEmpty;
    final mobileVerticalPadding = context.spacing.xs;
    final desktopVerticalPadding = context.spacing.sm;
    final effectivePadding =
        config.cardPadding ??
        EdgeInsets.fromLTRB(
          context.spacing.md,
          isMobile ? mobileVerticalPadding : desktopVerticalPadding,
          context.spacing.md,
          isMobile ? mobileVerticalPadding : desktopVerticalPadding,
        );

    final cardContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(config.cornerRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Semantics(
        button: true,
        label: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AdaptiveHaptic.lightImpact();
              onTap?.call();
            },
            borderRadius: BorderRadius.circular(config.cornerRadius),
            child: Padding(
              padding: effectivePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(context, theme),
                  if (hasDescription) ...[
                    SizedBox(height: context.spacing.xs),
                    Flexible(child: _buildDescription(context, theme)),
                  ] else if (config.showDescription) ...[
                    SizedBox(height: context.spacing.xxs),
                  ],
                  if (_hasMetaOrActions) ...[
                    SizedBox(
                      height: hasDescription
                          ? context.spacing.xxs
                          : context.spacing.xs,
                    ),
                    _buildMetaActionRow(context, theme),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: config.cardMargin ?? EdgeInsets.zero,
      child:
          (config.showIdentityColorBar || config.useGradientIdentityBar) &&
              (config.identityColor != null ||
                  config.identityGradientColors != null)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentityBar(context),
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

  Widget _buildIdentityBar(BuildContext context) {
    // Use gradient colors if available and enabled
    if (config.useGradientIdentityBar &&
        config.identityGradientColors != null &&
        config.identityGradientColors!.isNotEmpty) {
      return Container(
        width: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: config.identityGradientColors!,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(config.cornerRadius),
            bottomLeft: Radius.circular(config.cornerRadius),
          ),
        ),
      );
    }

    // Fall back to solid color
    if (config.identityColor != null) {
      return Container(
        width: 3,
        decoration: BoxDecoration(
          color: config.identityColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(config.cornerRadius),
            bottomLeft: Radius.circular(config.cornerRadius),
          ),
        ),
      );
    }

    // Default to violet gradient if no color specified
    return Container(
      width: 3,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.violetColors,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(config.cornerRadius),
          bottomLeft: Radius.circular(config.cornerRadius),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final titleStyle =
        (config.dense
                ? theme.textTheme.titleSmall
                : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      children: [
        if (config.showImage && config.imageUrl != null) ...[
          _buildImage(context, theme),
          SizedBox(width: isMobile ? context.spacing.xs : context.spacing.sm),
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
                SizedBox(height: context.spacing.xxs),
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
                SizedBox(height: context.spacing.xxs),
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
        SizedBox(width: context.spacing.sm),
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
            imageUrl: config.imageUrl,
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
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final iconSize = config.dense ? 22.0 : (isMobile ? 24.0 : 26.0);
    return IconButton(
      tooltip: l10n.podcast_play,
      onPressed: onPlay,
      icon: Icon(Icons.play_circle_outline, size: iconSize),
      iconSize: iconSize,
      color: theme.colorScheme.onSurfaceVariant,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: isMobile ? 32.0 : 36.0,
        minHeight: isMobile ? 32.0 : 36.0,
      ),
    );
  }

  Widget _buildDescription(BuildContext context, ThemeData theme) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    return Text(
      config.description!,
      style: (isMobile ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)
          ?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.2,
          ),
      maxLines: config.dense ? 2 : config.descriptionMaxLines,
      overflow: TextOverflow.ellipsis,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToLastDescent: false,
      ),
    );
  }

  Widget _buildMetaActionRow(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final downloadButtonSize =
        config.downloadButtonSize ??
        (config.dense
            ? 16.0
            : isMobile
            ? 17.0
            : 19.0);
    final queueButtonSize =
        config.queueButtonSize ?? (config.dense ? 22.0 : 24.0);
    final queueButtonIconSize = config.queueButtonIconSize ?? 19.0;
    final downloadQueueButtonSpacing = config.downloadQueueButtonSpacing ?? 0.0;
    final showDownloadAction =
        config.showDownloadButton &&
        config.episodeId != null &&
        config.audioUrl != null &&
        config.audioUrl!.isNotEmpty;
    final hasTrailingActions =
        showDownloadAction ||
        config.showQueueButton ||
        config.showSubscribeAction;
    final metadataInlineSpacing = context.spacing.xxs;
    final metadataTextStyle =
        (isMobile ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.2,
              fontSize: config.metadataFontSize,
              fontWeight: FontWeight.w400,
            );

    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (config.showSubscriptionBadge)
                  _buildSubscriptionBadge(theme, isMobile: isMobile),
                if (config.showSubscriptionBadge &&
                    (config.showDate || config.showDuration))
                  SizedBox(width: context.spacing.xs),
                if (config.showDate && config.date != null)
                  EpisodeCardUtils.buildDateMetadata(
                    date: config.date!,
                    theme: theme,
                    textStyle: metadataTextStyle,
                    spacing: metadataInlineSpacing,
                  ),
                if (config.showDate && config.showDuration)
                  SizedBox(width: context.spacing.xs),
                if (config.showDuration && config.formattedDuration != null)
                  EpisodeCardUtils.buildDurationMetadata(
                    formattedDuration: config.formattedDuration!,
                    theme: theme,
                    textStyle: metadataTextStyle,
                    spacing: metadataInlineSpacing,
                  ),
                if (additionalMetadata != null) ...additionalMetadata!,
              ],
            ),
          ),
        ),
        if (hasTrailingActions) SizedBox(width: context.spacing.xxs),
        if (showDownloadAction)
          DownloadButton(
            episodeId: config.episodeId!,
            audioUrl: config.audioUrl!,
            size: downloadButtonSize,
            title: config.episodeTitle,
            subscriptionTitle: config.subscriptionTitle,
            imageUrl: config.imageUrl,
            subscriptionImageUrl: config.subscriptionImageUrl,
            subscriptionId: config.subscriptionId,
            audioDuration: config.audioDuration,
            publishedAt: config.publishedAt,
          ),
        if (showDownloadAction && config.showQueueButton)
          SizedBox(width: downloadQueueButtonSpacing),
        if (config.showQueueButton)
          IconButton(
            tooltip: config.isAddingToQueue
                ? l10n.podcast_adding
                : l10n.podcast_add_to_queue,
            onPressed: config.isAddingToQueue ? null : onAddToQueue,
            style: EpisodeCardUtils.compactIconButtonStyle(
              theme,
              buttonSize: queueButtonSize,
            ),
            icon: config.isAddingToQueue
                ? SizedBox(
                    width: queueButtonIconSize,
                    height: queueButtonIconSize,
                    child: const CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.playlist_add, size: queueButtonIconSize),
          ),
        if (config.showSubscribeAction) ...[
          SizedBox(width: context.spacing.smMd),
          _buildSubscribeAction(context, theme),
        ],
      ],
    );
  }

  Widget _buildSubscriptionBadge(ThemeData theme, {required bool isMobile}) {
    final badgeBackgroundColor = theme.colorScheme.onSurfaceVariant;
    final badgeTextColor = theme.colorScheme.surface;
    final badgeTextStyle =
        (isMobile ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)
            ?.copyWith(
              color: badgeTextColor,
              fontSize: config.metadataFontSize,
              height: 1.2,
              fontWeight: FontWeight.w700,
            );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: config.dense ? 130 : 170),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: config.dense ? 6 : 10,
          vertical: config.dense ? 1 : 3,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor,
          borderRadius: BorderRadius.circular(config.dense ? 8 : 12),
        ),
        child: Text(
          config.subscriptionBadgeText ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: badgeTextStyle ?? AppTheme.metaSmall(badgeTextColor),
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
          padding: EdgeInsets.all(context.spacing.smMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: AppRadius.xsRadius,
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
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      );
    }

    return Tooltip(
      message: l10n.podcast_subscribe,
      child: IconButton(
        onPressed: onSubscribe,
        icon: const Icon(Icons.add_circle_outline),
        iconSize: 22,
        color: theme.colorScheme.onSurfaceVariant,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      ),
    );
  }
}
