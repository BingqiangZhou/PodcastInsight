part of 'podcast_playback_providers.dart';

@visibleForTesting
String playbackSnapshotStorageKeyForUser(String userId) {
  return '${kLastPlaybackSnapshotStorageKeyPrefix}_$userId';
}

@visibleForTesting
int resolveCompletedPositionMs(int currentPositionMs, int durationMs) {
  if (durationMs > 0) {
    return durationMs;
  }
  if (currentPositionMs < 0) {
    return 0;
  }
  return currentPositionMs;
}

double _effectiveFallbackPlaybackRate({
  required double currentValue,
  double? episodePlaybackRate,
}) {
  if (episodePlaybackRate != null && episodePlaybackRate > 0) {
    return episodePlaybackRate;
  }
  if (currentValue > 0) {
    return currentValue;
  }
  return 1.0;
}

String? _extractSubscriptionTitle(Map<String, dynamic>? subscription) {
  if (subscription == null) {
    return null;
  }

  final dynamic title = subscription['title'] ?? subscription['name'];
  if (title is String && title.trim().isNotEmpty) {
    return title;
  }
  return null;
}

@visibleForTesting
bool isDiscoverPreviewEpisode(PodcastEpisodeModel episode) {
  final metadata = episode.metadata;
  if (metadata == null) {
    return false;
  }

  final raw = metadata['discover_preview'];
  if (raw is bool) {
    return raw;
  }
  if (raw is String) {
    return raw.toLowerCase() == 'true';
  }
  if (raw is num) {
    return raw != 0;
  }
  return false;
}

@visibleForTesting
bool shouldSyncPlaybackToServer(PodcastEpisodeModel episode) {
  return !isDiscoverPreviewEpisode(episode);
}

@visibleForTesting
List<int> buildQueueOrderAfterAdd({
  required PodcastQueueModel queue,
  required int episodeId,
  required bool isPlaying,
  required int? playingEpisodeId,
}) {
  final orderedIds = queue.items.map((item) => item.episodeId).toList();
  orderedIds.removeWhere((id) => id == episodeId);

  var targetIndex = 0;
  final anchorEpisodeId = playingEpisodeId ?? queue.currentEpisodeId;
  if (anchorEpisodeId != null && episodeId != anchorEpisodeId) {
    final anchorIndex = orderedIds.indexOf(anchorEpisodeId);
    if (anchorIndex >= 0) {
      targetIndex = anchorIndex + 1;
    }
  } else if (isPlaying && orderedIds.isNotEmpty) {
    targetIndex = 1;
  }

  final clampedIndex = targetIndex.clamp(0, orderedIds.length);
  orderedIds.insert(clampedIndex, episodeId);
  return orderedIds;
}

@visibleForTesting
bool isSameEpisodeOrder(List<int> left, List<int> right) {
  return listEquals(left, right);
}

@visibleForTesting
bool shouldAdvanceQueueOnCompletion(AudioPlayerState state) {
  if (state.playSource == PlaySource.queue) {
    return true;
  }

  final currentEpisodeId = state.currentEpisode?.id;
  if (currentEpisodeId == null) {
    return false;
  }
  return state.queue.currentEpisodeId == currentEpisodeId;
}

@visibleForTesting
PodcastEpisodeModel mergeEpisodeForPlayback(
  PodcastEpisodeModel incoming,
  PodcastEpisodeDetailResponse latest,
) {
  final latestEpisode = latest.toEpisodeModel();
  final backendSubscriptionTitle = _extractSubscriptionTitle(
    latest.subscription,
  );
  final resolvedPlaybackRate = latestEpisode.playbackRate > 0
      ? latestEpisode.playbackRate
      : incoming.playbackRate;

  return latestEpisode.copyWith(
    subscriptionTitle: backendSubscriptionTitle ?? incoming.subscriptionTitle,
    subscriptionImageUrl:
        latestEpisode.subscriptionImageUrl ?? incoming.subscriptionImageUrl,
    description: latestEpisode.description ?? incoming.description,
    imageUrl: latestEpisode.imageUrl ?? incoming.imageUrl,
    itemLink: latestEpisode.itemLink ?? incoming.itemLink,
    transcriptUrl: latestEpisode.transcriptUrl ?? incoming.transcriptUrl,
    transcriptContent:
        latestEpisode.transcriptContent ?? incoming.transcriptContent,
    aiSummary: latestEpisode.aiSummary ?? incoming.aiSummary,
    summaryVersion: latestEpisode.summaryVersion ?? incoming.summaryVersion,
    aiConfidenceScore:
        latestEpisode.aiConfidenceScore ?? incoming.aiConfidenceScore,
    metadata: latestEpisode.metadata ?? incoming.metadata,
    playCount: latestEpisode.playCount > 0
        ? latestEpisode.playCount
        : incoming.playCount,
    lastPlayedAt: latestEpisode.lastPlayedAt ?? incoming.lastPlayedAt,
    playbackPosition:
        latestEpisode.playbackPosition ?? incoming.playbackPosition,
    audioDuration: latestEpisode.audioDuration ?? incoming.audioDuration,
    audioFileSize: latestEpisode.audioFileSize ?? incoming.audioFileSize,
    audioUrl: latestEpisode.audioUrl.isNotEmpty
        ? latestEpisode.audioUrl
        : incoming.audioUrl,
    playbackRate: resolvedPlaybackRate,
    isPlayed: latestEpisode.isPlayed || incoming.isPlayed,
  );
}

@visibleForTesting
Future<PodcastEpisodeModel> resolveEpisodeForPlayback(
  PodcastEpisodeModel incoming,
  Future<PodcastEpisodeDetailResponse> Function() fetchLatest,
) async {
  try {
    final latest = await fetchLatest();
    return mergeEpisodeForPlayback(incoming, latest);
  } catch (e) {
    logger.AppLogger.debug('[Playback] Failed to fetch latest episode data, using incoming: $e');
    return incoming;
  }
}

class _LastPlaybackSnapshot {
  final PodcastEpisodeModel episode;
  final int positionMs;
  final int durationMs;
  final double playbackRate;
  final DateTime? savedAt;

  const _LastPlaybackSnapshot({
    required this.episode,
    required this.positionMs,
    required this.durationMs,
    required this.playbackRate,
    this.savedAt,
  });
}
