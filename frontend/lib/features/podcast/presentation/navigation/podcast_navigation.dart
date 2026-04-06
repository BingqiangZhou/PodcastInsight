
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

/// Navigation arguments for podcast episodes page
class PodcastEpisodesPageArgs {

  const PodcastEpisodesPageArgs({
    required this.subscriptionId,
    this.podcastTitle,
    this.subscription,
  });

  /// Creates args from a subscription object
  factory PodcastEpisodesPageArgs.fromSubscription(
    PodcastSubscriptionModel subscription,
  ) {
    return PodcastEpisodesPageArgs(
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
      subscription: subscription,
    );
  }
  final int subscriptionId;
  final String? podcastTitle;
  final PodcastSubscriptionModel? subscription;

  /// Extracts args from GoRouter state
  static PodcastEpisodesPageArgs? extractFromState(GoRouterState state) {
    final subscriptionIdStr = state.pathParameters['subscriptionId'];
    if (subscriptionIdStr == null) return null;

    final subscriptionId = int.tryParse(subscriptionIdStr);
    if (subscriptionId == null) return null;

    final subscription = state.extra as PodcastSubscriptionModel?;

    return PodcastEpisodesPageArgs(
      subscriptionId: subscriptionId,
      podcastTitle: state.uri.queryParameters['title'] ?? subscription?.title,
      subscription: subscription,
    );
  }
}

/// Navigation arguments for podcast episode detail page
class PodcastEpisodeDetailPageArgs {

  const PodcastEpisodeDetailPageArgs({
    required this.episodeId,
    required this.subscriptionId,
    this.episodeTitle,
  });
  final int episodeId;
  final int subscriptionId;
  final String? episodeTitle;

  /// Extracts args from GoRouter state
  static PodcastEpisodeDetailPageArgs? extractFromState(GoRouterState state) {
    final episodeIdStr = state.pathParameters['episodeId'];
    final subscriptionIdStr = state.pathParameters['subscriptionId'];

    if (episodeIdStr == null || subscriptionIdStr == null) return null;

    final episodeId = int.tryParse(episodeIdStr);
    final subscriptionId = int.tryParse(subscriptionIdStr);

    if (episodeId == null || subscriptionId == null) return null;

    return PodcastEpisodeDetailPageArgs(
      episodeId: episodeId,
      subscriptionId: subscriptionId,
      episodeTitle: state.uri.queryParameters['title'],
    );
  }
}

/// Helper class for podcast navigation
class PodcastNavigation {
  const PodcastNavigation._();

  static BuildContext? _resolveRoutingContext(BuildContext context) {
    // Use maybeOf instead of try-catch for cleaner control flow
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return context;
    }
    return appNavigatorKey.currentContext;
  }

  /// Navigate to episodes page
  static void goToEpisodes(
    BuildContext context, {
    required int subscriptionId,
    String? podcastTitle,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    final query = podcastTitle != null
        ? {'title': podcastTitle}
        : <String, dynamic>{};
    GoRouter.of(routingContext).pushNamed(
      'podcastEpisodes',
      pathParameters: {'subscriptionId': subscriptionId.toString()},
      queryParameters: query,
    );
  }

  /// Navigate to episodes page from subscription object
  static void goToEpisodesFromSubscription(
    BuildContext context,
    PodcastSubscriptionModel subscription,
  ) {
    goToEpisodes(
      context,
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
    );
  }

  /// Navigate to episode detail page
  static void goToEpisodeDetail(
    BuildContext context, {
    required int episodeId,
    required int subscriptionId,
    String? episodeTitle,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    final query = episodeTitle != null
        ? {'title': episodeTitle}
        : <String, dynamic>{};
    GoRouter.of(routingContext).pushNamed(
      'episodeDetail',
      pathParameters: {
        'subscriptionId': subscriptionId.toString(),
        'episodeId': episodeId.toString(),
      },
      queryParameters: query,
    );
  }

  /// Navigate to daily report page
  static void goToDailyReport(
    BuildContext context, {
    DateTime? date,
    String? source,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    GoRouter.of(routingContext).pushNamed(
      'dailyReport',
      queryParameters: {
        if (date != null) 'date': EpisodeCardUtils.formatDate(date),
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
  }

  /// Navigate to highlights page
  static void goToHighlights(
    BuildContext context, {
    DateTime? date,
    String? source,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    GoRouter.of(routingContext).pushNamed(
      'highlights',
      queryParameters: {
        if (date != null) 'date': EpisodeCardUtils.formatDate(date),
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
  }

  /// Navigate to podcast list page deterministically
  static void popToList(BuildContext context) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext != null) {
      GoRouter.of(routingContext).go('/discover');
    }
  }
}
