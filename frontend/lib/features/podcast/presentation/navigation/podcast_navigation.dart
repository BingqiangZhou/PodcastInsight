// ignore_for_file: use_null_aware_elements

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../data/models/podcast_subscription_model.dart';
import '../widgets/shared/episode_card_utils.dart';

/// Navigation arguments for podcast episodes page
class PodcastEpisodesPageArgs {
  final int subscriptionId;
  final String? podcastTitle;
  final PodcastSubscriptionModel? subscription;

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
  final int episodeId;
  final int subscriptionId;
  final String? episodeTitle;

  const PodcastEpisodeDetailPageArgs({
    required this.episodeId,
    required this.subscriptionId,
    this.episodeTitle,
  });

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
    try {
      GoRouter.of(context);
      return context;
    } catch (e, stackTrace) {
      logger.AppLogger.debug(
        '[PodcastNavigation] GoRouter not found in context, falling back to appNavigatorKey: $e',
      );
      logger.AppLogger.debug('[PodcastNavigation] Stack trace: $stackTrace');
      return appNavigatorKey.currentContext;
    }
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

  /// Pop to podcast list
  static void popToList(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.settings.name == 'podcast');
  }
}
