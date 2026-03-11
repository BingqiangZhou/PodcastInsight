import 'package:equatable/equatable.dart';
import 'podcast_episode_model.dart';
import 'podcast_queue_model.dart';

enum ProcessingState { idle, loading, buffering, ready, completed }

enum PlaySource { direct, queue }

// AudioPlayerState model
class AudioPlayerState extends Equatable {
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
      error: error ?? this.error,
      sleepTimerEndTime: clearSleepTimer
          ? null
          : (sleepTimerEndTime ?? this.sleepTimerEndTime),
      sleepTimerAfterEpisode: clearSleepTimer
          ? false
          : (sleepTimerAfterEpisode ?? this.sleepTimerAfterEpisode),
      sleepTimerRemainingLabel: clearSleepTimer
          ? null
          : (sleepTimerRemainingLabel ?? this.sleepTimerRemainingLabel),
    );
  }

  bool get isSleepTimerActive =>
      sleepTimerEndTime != null || sleepTimerAfterEpisode;

  double get progress {
    if (duration == 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  String get formattedPosition {
    final duration = Duration(milliseconds: position);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final duration = Duration(milliseconds: this.duration);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
