// ignore_for_file: use_null_aware_elements

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/podcast_subscription_model.dart';

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

/// Navigation arguments for podcast player page
class PodcastPlayerPageArgs {
  final int episodeId;
  final int subscriptionId;
  final String? episodeTitle;
  final String? audioUrl;
  final int? startPosition;

  const PodcastPlayerPageArgs({
    required this.episodeId,
    required this.subscriptionId,
    this.episodeTitle,
    this.audioUrl,
    this.startPosition,
  });

  /// Extracts args from GoRouter state
  static PodcastPlayerPageArgs? extractFromState(GoRouterState state) {
    final episodeIdStr = state.pathParameters['episodeId'];
    final subscriptionIdStr = state.uri.queryParameters['subscriptionId'];

    if (episodeIdStr == null || subscriptionIdStr == null) return null;

    final episodeId = int.tryParse(episodeIdStr);
    final subscriptionId = int.tryParse(subscriptionIdStr);

    if (episodeId == null || subscriptionId == null) return null;

    final startPositionStr = state.uri.queryParameters['position'];
    final startPosition = startPositionStr != null
        ? int.tryParse(startPositionStr)
        : null;

    return PodcastPlayerPageArgs(
      episodeId: episodeId,
      subscriptionId: subscriptionId,
      episodeTitle: state.uri.queryParameters['title'],
      audioUrl: state.uri.queryParameters['audioUrl'],
      startPosition: startPosition,
    );
  }
}

/// Helper class for podcast navigation
class PodcastNavigation {
  const PodcastNavigation._();

  /// Navigate to episodes page
  static void goToEpisodes(
    BuildContext context, {
    required int subscriptionId,
    String? podcastTitle,
  }) {
    final query = podcastTitle != null
        ? {'title': podcastTitle}
        : <String, dynamic>{};
    context.pushNamed(
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
    final query = episodeTitle != null
        ? {'title': episodeTitle}
        : <String, dynamic>{};
    context.pushNamed(
      'episodeDetail',
      pathParameters: {
        'subscriptionId': subscriptionId.toString(),
        'episodeId': episodeId.toString(),
      },
      queryParameters: query,
    );
  }

  /// Navigate to player page
  static void goToPlayer(
    BuildContext context, {
    required int episodeId,
    required int subscriptionId,
    String? episodeTitle,
    String? audioUrl,
    int? startPosition,
  }) {
    context.pushNamed(
      'episodePlayer',
      pathParameters: {'episodeId': episodeId.toString()},
      queryParameters: {
        'subscriptionId': subscriptionId.toString(),
        if (episodeTitle case final title?) 'title': title,
        if (audioUrl case final resolvedAudioUrl?) 'audioUrl': resolvedAudioUrl,
        if (startPosition != null) 'position': startPosition.toString(),
      },
    );
  }

  /// Navigate to daily report page
  static void goToDailyReport(
    BuildContext context, {
    DateTime? date,
    String? source,
  }) {
    context.pushNamed(
      'dailyReport',
      queryParameters: {
        if (date != null) 'date': _formatDateOnly(date),
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
  }

  /// Pop to podcast list
  static void popToList(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.settings.name == 'podcast');
  }
}

String _formatDateOnly(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
