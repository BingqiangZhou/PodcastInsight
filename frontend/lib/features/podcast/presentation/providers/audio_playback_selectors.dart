import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/podcast_episode_model.dart';
import 'podcast_providers.dart';

typedef AudioTransportState = ({
  bool isPlaying,
  bool isLoading,
  double playbackRate,
  bool isSleepTimerActive,
  int positionMs,
  int durationMs,
});

typedef AudioMiniProgress = ({
  double progress,
  String formattedPosition,
  String formattedDuration,
  int positionMs,
  int durationMs,
});

typedef AudioPlayPauseState = ({bool isPlaying, bool isLoading});

typedef AudioCurrentQueueProgress = ({
  int? currentEpisodeId,
  int positionMs,
  int durationMs,
  String formattedPosition,
  String formattedDuration,
});

final audioCurrentEpisodeProvider = Provider<PodcastEpisodeModel?>((ref) {
  return ref.watch(audioPlayerProvider.select((state) => state.currentEpisode));
});

final audioCurrentEpisodeIdProvider = Provider<int?>((ref) {
  return ref.watch(
    audioPlayerProvider.select((state) => state.currentEpisode?.id),
  );
});

final audioTransportStateProvider = Provider<AudioTransportState>((ref) {
  return ref.watch(
    audioPlayerProvider.select(
      (state) => (
        isPlaying: state.isPlaying,
        isLoading: state.isLoading,
        playbackRate: state.playbackRate,
        isSleepTimerActive: state.isSleepTimerActive,
        positionMs: state.position,
        durationMs: state.duration,
      ),
    ),
  );
});

final audioPlayPauseStateProvider = Provider<AudioPlayPauseState>((ref) {
  return ref.watch(
    audioPlayerProvider.select(
      (state) => (isPlaying: state.isPlaying, isLoading: state.isLoading),
    ),
  );
});

final audioPlaybackRateProvider = Provider<double>((ref) {
  return ref.watch(audioPlayerProvider.select((state) => state.playbackRate));
});

final audioSleepTimerActiveProvider = Provider<bool>((ref) {
  return ref.watch(
    audioPlayerProvider.select((state) => state.isSleepTimerActive),
  );
});

final audioMiniProgressProvider = Provider<AudioMiniProgress>((ref) {
  return ref.watch(
    audioPlayerProvider.select(
      (state) => (
        progress: state.progress,
        formattedPosition: state.formattedPosition,
        formattedDuration: state.formattedDuration,
        positionMs: state.position,
        durationMs: state.duration,
      ),
    ),
  );
});

final audioCurrentQueueProgressProvider = Provider<AudioCurrentQueueProgress>((
  ref,
) {
  return ref.watch(
    audioPlayerProvider.select(
      (state) => (
        currentEpisodeId: state.currentEpisode?.id,
        positionMs: state.position,
        durationMs: state.duration,
        formattedPosition: state.formattedPosition,
        formattedDuration: state.formattedDuration,
      ),
    ),
  );
});

final audioDurationForEpisodeProvider = Provider.family<int?, int>((
  ref,
  episodeId,
) {
  final tuple = ref.watch(
    audioPlayerProvider.select(
      (state) => (
        currentEpisodeId: state.currentEpisode?.id,
        currentDurationMs: state.duration,
      ),
    ),
  );
  if (tuple.currentEpisodeId == episodeId && tuple.currentDurationMs > 0) {
    return tuple.currentDurationMs;
  }
  return null;
});

final audioQueuePositionProvider = Provider.family<int?, int>((ref, episodeId) {
  return ref.watch(
    audioPlayerProvider.select((state) {
      if (state.currentEpisode?.id == episodeId) {
        return state.position;
      }

      for (final item in state.queue.items) {
        if (item.episodeId == episodeId) {
          final playbackPosition = item.playbackPosition;
          if (playbackPosition != null && playbackPosition > 0) {
            return playbackPosition * 1000;
          }
          break;
        }
      }
      return null;
    }),
  );
});
