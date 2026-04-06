import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:riverpod/src/providers/provider.dart';

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

final ProviderFamily<int?, int> audioDurationForEpisodeProvider = Provider.family<int?, int>((
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

final ProviderFamily<int?, int> audioQueuePositionProvider = Provider.family<int?, int>((ref, episodeId) {
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

/// Episode play state for determining button display (play/resume/playing)
typedef AudioEpisodePlayState = ({
  int? currentEpisodeId,
  bool isPlaying,
  ProcessingState? processingState,
  int currentPositionMs,
});

/// Provider for episode play state - used by play buttons to determine their state
final audioEpisodePlayStateProvider = Provider<AudioEpisodePlayState>((ref) {
  return ref.watch(
    audioPlayerProvider.select(
      (state) => (
        currentEpisodeId: state.currentEpisode?.id,
        isPlaying: state.isPlaying,
        processingState: state.processingState,
        currentPositionMs: state.position,
      ),
    ),
  );
});

/// Provider for queue syncing state
final audioQueueSyncingProvider = Provider<bool>((ref) {
  return ref.watch(
    audioPlayerProvider.select((state) => state.queueSyncing),
  );
});
