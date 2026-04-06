import 'package:equatable/equatable.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';

enum ProcessingState { idle, loading, buffering, ready, completed }

enum PlaySource { direct, queue }

// AudioPlayerState model
class AudioPlayerState extends Equatable {

  const AudioPlayerState({
    this.currentEpisode,
    this.queue = const PodcastQueueModel(),
    this.currentQueueEpisodeId,
    this.playSource = PlaySource.direct,
    this.queueSyncing = false,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = 0,
    this.duration = 0,
    this.playbackRate = 1.0,
    this.processingState,
    this.error,
    this.sleepTimerEndTime,
    this.sleepTimerAfterEpisode = false,
    this.sleepTimerRemainingLabel,
  });
  final PodcastEpisodeModel? currentEpisode;
  final PodcastQueueModel queue;
  final int? currentQueueEpisodeId;
  final PlaySource playSource;
  final bool queueSyncing;
  final bool isPlaying;
  final bool isLoading;
  final int position;
  final int duration;
  final double playbackRate;
  final ProcessingState? processingState;
  final String? error;
  final DateTime? sleepTimerEndTime;
  final bool sleepTimerAfterEpisode;
  final String? sleepTimerRemainingLabel;

  AudioPlayerState copyWith({
    PodcastEpisodeModel? currentEpisode,
    PodcastQueueModel? queue,
    int? currentQueueEpisodeId,
    PlaySource? playSource,
    bool? queueSyncing,
    bool? isPlaying,
    bool? isLoading,
    int? position,
    int? duration,
    double? playbackRate,
    ProcessingState? processingState,
    String? error,
    bool clearError = false,
    DateTime? sleepTimerEndTime,
    bool? sleepTimerAfterEpisode,
    String? sleepTimerRemainingLabel,
    bool clearCurrentEpisode = false,
    bool clearCurrentQueueEpisodeId = false,
    bool clearSleepTimer = false,
  }) {
    return AudioPlayerState(
      currentEpisode: clearCurrentEpisode
          ? null
          : (currentEpisode ?? this.currentEpisode),
      queue: queue ?? this.queue,
      currentQueueEpisodeId: clearCurrentQueueEpisodeId
          ? null
          : (currentQueueEpisodeId ?? this.currentQueueEpisodeId),
      playSource: playSource ?? this.playSource,
      queueSyncing: queueSyncing ?? this.queueSyncing,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackRate: playbackRate ?? this.playbackRate,
      processingState: processingState ?? this.processingState,
      error: clearError ? null : (error ?? this.error),
      sleepTimerEndTime: clearSleepTimer
          ? null
          : (sleepTimerEndTime ?? this.sleepTimerEndTime),
      sleepTimerAfterEpisode: !clearSleepTimer && (sleepTimerAfterEpisode ?? this.sleepTimerAfterEpisode),
      sleepTimerRemainingLabel: clearSleepTimer
          ? null
          : (sleepTimerRemainingLabel ?? this.sleepTimerRemainingLabel),
    );
  }

  bool get isSleepTimerActive =>
      sleepTimerEndTime != null || sleepTimerAfterEpisode;

  double get progress {
    if (duration == 0) return 0;
    return (position / duration).clamp(0.0, 1.0);
  }

  String get formattedPosition {
    return TimeFormatter.formatDuration(
      Duration(milliseconds: position),
      padHours: false,
    );
  }

  String get formattedDuration {
    return TimeFormatter.formatDuration(
      Duration(milliseconds: duration),
      padHours: false,
    );
  }

  @override
  List<Object?> get props => [
    currentEpisode,
    queue,
    currentQueueEpisodeId,
    playSource,
    queueSyncing,
    isPlaying,
    isLoading,
    position,
    duration,
    playbackRate,
    processingState,
    error,
    sleepTimerEndTime,
    sleepTimerAfterEpisode,
    sleepTimerRemainingLabel,
  ];
}
