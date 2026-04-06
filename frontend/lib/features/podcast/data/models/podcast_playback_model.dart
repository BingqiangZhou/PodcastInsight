import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_playback_model.g.dart';

@JsonSerializable()
class PodcastPlaybackStateResponse extends Equatable {

  const PodcastPlaybackStateResponse({
    required this.episodeId,
    required this.currentPosition,
    required this.isPlaying,
    required this.playbackRate,
    required this.playCount,
    required this.lastUpdatedAt,
    required this.progressPercentage,
    required this.remainingTime,
  });

  factory PodcastPlaybackStateResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastPlaybackStateResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'current_position')
  final int currentPosition;
  @JsonKey(name: 'is_playing', defaultValue: false)
  final bool isPlaying;
  @JsonKey(name: 'playback_rate')
  final double playbackRate;
  @JsonKey(name: 'play_count')
  final int playCount;
  @JsonKey(name: 'last_updated_at')
  final DateTime lastUpdatedAt;
  @JsonKey(name: 'progress_percentage')
  final double progressPercentage;
  @JsonKey(name: 'remaining_time')
  final int remainingTime;

  Map<String, dynamic> toJson() => _$PodcastPlaybackStateResponseToJson(this);

  @override
  List<Object?> get props => [
    episodeId,
    currentPosition,
    isPlaying,
    playbackRate,
    playCount,
    lastUpdatedAt,
    progressPercentage,
    remainingTime,
  ];
}

@JsonSerializable()
class PodcastPlaybackUpdateRequest extends Equatable {

  const PodcastPlaybackUpdateRequest({
    required this.position,
    required this.isPlaying,
    this.playbackRate = 1.0,
  });
  final int position;
  @JsonKey(name: 'is_playing', defaultValue: false)
  final bool isPlaying;
  @JsonKey(name: 'playback_rate')
  final double playbackRate;

  Map<String, dynamic> toJson() => _$PodcastPlaybackUpdateRequestToJson(this);

  @override
  List<Object?> get props => [position, isPlaying, playbackRate];
}

@JsonSerializable()
class PlaybackRateEffectiveResponse extends Equatable {

  const PlaybackRateEffectiveResponse({
    required this.globalPlaybackRate,
    required this.subscriptionPlaybackRate,
    required this.effectivePlaybackRate,
    required this.source,
  });

  factory PlaybackRateEffectiveResponse.fromJson(Map<String, dynamic> json) =>
      _$PlaybackRateEffectiveResponseFromJson(json);
  @JsonKey(name: 'global_playback_rate')
  final double globalPlaybackRate;
  @JsonKey(name: 'subscription_playback_rate')
  final double? subscriptionPlaybackRate;
  @JsonKey(name: 'effective_playback_rate')
  final double effectivePlaybackRate;
  final String source;

  Map<String, dynamic> toJson() => _$PlaybackRateEffectiveResponseToJson(this);

  @override
  List<Object?> get props => [
    globalPlaybackRate,
    subscriptionPlaybackRate,
    effectivePlaybackRate,
    source,
  ];
}

@JsonSerializable()
class PlaybackRateApplyRequest extends Equatable {

  const PlaybackRateApplyRequest({
    required this.playbackRate,
    required this.applyToSubscription,
    this.subscriptionId,
  });

  factory PlaybackRateApplyRequest.fromJson(Map<String, dynamic> json) =>
      _$PlaybackRateApplyRequestFromJson(json);
  @JsonKey(name: 'playback_rate')
  final double playbackRate;
  @JsonKey(name: 'subscription_id')
  final int? subscriptionId;
  @JsonKey(name: 'apply_to_subscription')
  final bool applyToSubscription;

  Map<String, dynamic> toJson() => _$PlaybackRateApplyRequestToJson(this);

  @override
  List<Object?> get props => [
    playbackRate,
    subscriptionId,
    applyToSubscription,
  ];
}

@JsonSerializable()
class PodcastSummaryResponse extends Equatable {

  const PodcastSummaryResponse({
    required this.episodeId,
    required this.summary,
    required this.version,
    required this.transcriptUsed, required this.generatedAt, required this.wordCount, this.confidenceScore,
    this.modelUsed,
    this.processingTime,
  });

  factory PodcastSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastSummaryResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  final String summary;
  final String version;
  @JsonKey(name: 'confidence_score')
  final double? confidenceScore;
  @JsonKey(name: 'transcript_used', defaultValue: false)
  final bool transcriptUsed;
  @JsonKey(name: 'generated_at')
  final DateTime generatedAt;
  @JsonKey(name: 'word_count')
  final int wordCount;
  @JsonKey(name: 'model_used')
  final String? modelUsed;
  @JsonKey(name: 'processing_time')
  final double? processingTime;

  Map<String, dynamic> toJson() => _$PodcastSummaryResponseToJson(this);

  @override
  List<Object?> get props => [
    episodeId,
    summary,
    version,
    confidenceScore,
    transcriptUsed,
    generatedAt,
    wordCount,
    modelUsed,
    processingTime,
  ];
}

@JsonSerializable()
class PodcastSummaryStartResponse extends Equatable {

  const PodcastSummaryStartResponse({
    required this.episodeId,
    required this.summaryStatus,
    required this.acceptedAt,
    required this.messageEn,
    required this.messageZh,
  });

  factory PodcastSummaryStartResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastSummaryStartResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'summary_status')
  final String summaryStatus;
  @JsonKey(name: 'accepted_at')
  final DateTime acceptedAt;
  @JsonKey(name: 'message_en')
  final String messageEn;
  @JsonKey(name: 'message_zh')
  final String messageZh;

  Map<String, dynamic> toJson() => _$PodcastSummaryStartResponseToJson(this);

  @override
  List<Object?> get props => [
    episodeId,
    summaryStatus,
    acceptedAt,
    messageEn,
    messageZh,
  ];
}

@JsonSerializable()
class PodcastSummaryRequest extends Equatable {

  const PodcastSummaryRequest({
    this.forceRegenerate = false,
    this.useTranscript,
    this.summaryModel,
    this.customPrompt,
  });
  @JsonKey(name: 'force_regenerate')
  final bool forceRegenerate;
  @JsonKey(name: 'use_transcript')
  final bool? useTranscript;
  @JsonKey(name: 'summary_model')
  final String? summaryModel;
  @JsonKey(name: 'custom_prompt')
  final String? customPrompt;

  Map<String, dynamic> toJson() => _$PodcastSummaryRequestToJson(this);

  @override
  List<Object?> get props => [
    forceRegenerate,
    useTranscript,
    summaryModel,
    customPrompt,
  ];
}

@JsonSerializable()
class PodcastStatsResponse extends Equatable {

  const PodcastStatsResponse({
    required this.totalSubscriptions,
    required this.totalEpisodes,
    required this.totalPlaytime,
    required this.summariesGenerated,
    required this.pendingSummaries,
    required this.recentlyPlayed,
    required this.topCategories,
    required this.listeningStreak,
  });

  factory PodcastStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastStatsResponseFromJson(json);
  @JsonKey(name: 'total_subscriptions')
  final int totalSubscriptions;
  @JsonKey(name: 'total_episodes')
  final int totalEpisodes;
  @JsonKey(name: 'total_playtime')
  final int totalPlaytime;
  @JsonKey(name: 'summaries_generated')
  final int summariesGenerated;
  @JsonKey(name: 'pending_summaries')
  final int pendingSummaries;
  @JsonKey(name: 'recently_played')
  final List<Map<String, dynamic>> recentlyPlayed;
  @JsonKey(name: 'top_categories')
  final List<Map<String, dynamic>> topCategories;
  @JsonKey(name: 'listening_streak')
  final int listeningStreak;

  Map<String, dynamic> toJson() => _$PodcastStatsResponseToJson(this);

  @override
  List<Object?> get props => [
    totalSubscriptions,
    totalEpisodes,
    totalPlaytime,
    summariesGenerated,
    pendingSummaries,
    recentlyPlayed,
    topCategories,
    listeningStreak,
  ];
}

@JsonSerializable()
class PodcastSearchFilter extends Equatable {

  const PodcastSearchFilter({
    this.query,
    this.categoryId,
    this.status,
    this.hasSummary,
    this.dateFrom,
    this.dateTo,
    this.subscriptionId,
    this.isPlayed,
    this.durationMin,
    this.durationMax,
  });
  final String? query;
  @JsonKey(name: 'category_id')
  final int? categoryId;
  final String? status;
  @JsonKey(name: 'has_summary')
  final bool? hasSummary;
  @JsonKey(name: 'date_from')
  final DateTime? dateFrom;
  @JsonKey(name: 'date_to')
  final DateTime? dateTo;
  @JsonKey(name: 'subscription_id')
  final int? subscriptionId;
  @JsonKey(name: 'is_played')
  final bool? isPlayed;
  @JsonKey(name: 'duration_min')
  final int? durationMin;
  @JsonKey(name: 'duration_max')
  final int? durationMax;

  Map<String, dynamic> toJson() => _$PodcastSearchFilterToJson(this);

  @override
  List<Object?> get props => [
    query,
    categoryId,
    status,
    hasSummary,
    dateFrom,
    dateTo,
    subscriptionId,
    isPlayed,
    durationMin,
    durationMax,
  ];
}

/// AI总结模型信息
@JsonSerializable()
class SummaryModelInfo extends Equatable {

  const SummaryModelInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.provider,
    required this.modelId,
    required this.isDefault,
  });

  factory SummaryModelInfo.fromJson(Map<String, dynamic> json) =>
      _$SummaryModelInfoFromJson(json);
  final int id;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String provider;
  @JsonKey(name: 'model_id')
  final String modelId;
  @JsonKey(name: 'is_default')
  final bool isDefault;

  Map<String, dynamic> toJson() => _$SummaryModelInfoToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    displayName,
    provider,
    modelId,
    isDefault,
  ];
}

/// 可用总结模型列表响应
@JsonSerializable()
class SummaryModelsResponse extends Equatable {

  const SummaryModelsResponse({required this.models, required this.total});

  factory SummaryModelsResponse.fromJson(Map<String, dynamic> json) =>
      _$SummaryModelsResponseFromJson(json);
  final List<SummaryModelInfo> models;
  final int total;

  Map<String, dynamic> toJson() => _$SummaryModelsResponseToJson(this);

  @override
  List<Object?> get props => [models, total];
}
