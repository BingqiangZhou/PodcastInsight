// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_playback_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PodcastPlaybackStateResponse _$PodcastPlaybackStateResponseFromJson(
  Map<String, dynamic> json,
) => PodcastPlaybackStateResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  currentPosition: (json['current_position'] as num).toInt(),
  isPlaying: json['is_playing'] as bool? ?? false,
  playbackRate: (json['playback_rate'] as num).toDouble(),
  playCount: (json['play_count'] as num).toInt(),
  lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
  progressPercentage: (json['progress_percentage'] as num).toDouble(),
  remainingTime: (json['remaining_time'] as num).toInt(),
);

Map<String, dynamic> _$PodcastPlaybackStateResponseToJson(
  PodcastPlaybackStateResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'current_position': instance.currentPosition,
  'is_playing': instance.isPlaying,
  'playback_rate': instance.playbackRate,
  'play_count': instance.playCount,
  'last_updated_at': instance.lastUpdatedAt.toIso8601String(),
  'progress_percentage': instance.progressPercentage,
  'remaining_time': instance.remainingTime,
};

PodcastPlaybackUpdateRequest _$PodcastPlaybackUpdateRequestFromJson(
  Map<String, dynamic> json,
) => PodcastPlaybackUpdateRequest(
  position: (json['position'] as num).toInt(),
  isPlaying: json['is_playing'] as bool? ?? false,
  playbackRate: (json['playback_rate'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$PodcastPlaybackUpdateRequestToJson(
  PodcastPlaybackUpdateRequest instance,
) => <String, dynamic>{
  'position': instance.position,
  'is_playing': instance.isPlaying,
  'playback_rate': instance.playbackRate,
};

PlaybackRateEffectiveResponse _$PlaybackRateEffectiveResponseFromJson(
  Map<String, dynamic> json,
) => PlaybackRateEffectiveResponse(
  globalPlaybackRate: (json['global_playback_rate'] as num).toDouble(),
  subscriptionPlaybackRate: (json['subscription_playback_rate'] as num?)
      ?.toDouble(),
  effectivePlaybackRate: (json['effective_playback_rate'] as num).toDouble(),
  source: json['source'] as String,
);

Map<String, dynamic> _$PlaybackRateEffectiveResponseToJson(
  PlaybackRateEffectiveResponse instance,
) => <String, dynamic>{
  'global_playback_rate': instance.globalPlaybackRate,
  'subscription_playback_rate': instance.subscriptionPlaybackRate,
  'effective_playback_rate': instance.effectivePlaybackRate,
  'source': instance.source,
};

PlaybackRateApplyRequest _$PlaybackRateApplyRequestFromJson(
  Map<String, dynamic> json,
) => PlaybackRateApplyRequest(
  playbackRate: (json['playback_rate'] as num).toDouble(),
  applyToSubscription: json['apply_to_subscription'] as bool,
  subscriptionId: (json['subscription_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlaybackRateApplyRequestToJson(
  PlaybackRateApplyRequest instance,
) => <String, dynamic>{
  'playback_rate': instance.playbackRate,
  'subscription_id': instance.subscriptionId,
  'apply_to_subscription': instance.applyToSubscription,
};

PodcastSummaryResponse _$PodcastSummaryResponseFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  summary: json['summary'] as String,
  version: json['version'] as String,
  confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
  transcriptUsed: json['transcript_used'] as bool? ?? false,
  generatedAt: DateTime.parse(json['generated_at'] as String),
  wordCount: (json['word_count'] as num).toInt(),
  modelUsed: json['model_used'] as String?,
  processingTime: (json['processing_time'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PodcastSummaryResponseToJson(
  PodcastSummaryResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'summary': instance.summary,
  'version': instance.version,
  'confidence_score': instance.confidenceScore,
  'transcript_used': instance.transcriptUsed,
  'generated_at': instance.generatedAt.toIso8601String(),
  'word_count': instance.wordCount,
  'model_used': instance.modelUsed,
  'processing_time': instance.processingTime,
};

PodcastSummaryStartResponse _$PodcastSummaryStartResponseFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryStartResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  summaryStatus: json['summary_status'] as String,
  acceptedAt: DateTime.parse(json['accepted_at'] as String),
  messageEn: json['message_en'] as String,
  messageZh: json['message_zh'] as String,
);

Map<String, dynamic> _$PodcastSummaryStartResponseToJson(
  PodcastSummaryStartResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'summary_status': instance.summaryStatus,
  'accepted_at': instance.acceptedAt.toIso8601String(),
  'message_en': instance.messageEn,
  'message_zh': instance.messageZh,
};

PodcastSummaryRequest _$PodcastSummaryRequestFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryRequest(
  forceRegenerate: json['force_regenerate'] as bool? ?? false,
  useTranscript: json['use_transcript'] as bool?,
  summaryModel: json['summary_model'] as String?,
  customPrompt: json['custom_prompt'] as String?,
);

Map<String, dynamic> _$PodcastSummaryRequestToJson(
  PodcastSummaryRequest instance,
) => <String, dynamic>{
  'force_regenerate': instance.forceRegenerate,
  'use_transcript': instance.useTranscript,
  'summary_model': instance.summaryModel,
  'custom_prompt': instance.customPrompt,
};

PodcastStatsResponse _$PodcastStatsResponseFromJson(
  Map<String, dynamic> json,
) => PodcastStatsResponse(
  totalSubscriptions: (json['total_subscriptions'] as num).toInt(),
  totalEpisodes: (json['total_episodes'] as num).toInt(),
  totalPlaytime: (json['total_playtime'] as num).toInt(),
  summariesGenerated: (json['summaries_generated'] as num).toInt(),
  pendingSummaries: (json['pending_summaries'] as num).toInt(),
  recentlyPlayed: (json['recently_played'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList(),
  topCategories: (json['top_categories'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList(),
  listeningStreak: (json['listening_streak'] as num).toInt(),
);

Map<String, dynamic> _$PodcastStatsResponseToJson(
  PodcastStatsResponse instance,
) => <String, dynamic>{
  'total_subscriptions': instance.totalSubscriptions,
  'total_episodes': instance.totalEpisodes,
  'total_playtime': instance.totalPlaytime,
  'summaries_generated': instance.summariesGenerated,
  'pending_summaries': instance.pendingSummaries,
  'recently_played': instance.recentlyPlayed,
  'top_categories': instance.topCategories,
  'listening_streak': instance.listeningStreak,
};

PodcastSearchFilter _$PodcastSearchFilterFromJson(Map<String, dynamic> json) =>
    PodcastSearchFilter(
      query: json['query'] as String?,
      categoryId: (json['category_id'] as num?)?.toInt(),
      status: json['status'] as String?,
      hasSummary: json['has_summary'] as bool?,
      dateFrom: json['date_from'] == null
          ? null
          : DateTime.parse(json['date_from'] as String),
      dateTo: json['date_to'] == null
          ? null
          : DateTime.parse(json['date_to'] as String),
      subscriptionId: (json['subscription_id'] as num?)?.toInt(),
      isPlayed: json['is_played'] as bool?,
      durationMin: (json['duration_min'] as num?)?.toInt(),
      durationMax: (json['duration_max'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PodcastSearchFilterToJson(
  PodcastSearchFilter instance,
) => <String, dynamic>{
  'query': instance.query,
  'category_id': instance.categoryId,
  'status': instance.status,
  'has_summary': instance.hasSummary,
  'date_from': instance.dateFrom?.toIso8601String(),
  'date_to': instance.dateTo?.toIso8601String(),
  'subscription_id': instance.subscriptionId,
  'is_played': instance.isPlayed,
  'duration_min': instance.durationMin,
  'duration_max': instance.durationMax,
};

SummaryModelInfo _$SummaryModelInfoFromJson(Map<String, dynamic> json) =>
    SummaryModelInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      provider: json['provider'] as String,
      modelId: json['model_id'] as String,
      isDefault: json['is_default'] as bool,
    );

Map<String, dynamic> _$SummaryModelInfoToJson(SummaryModelInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': instance.displayName,
      'provider': instance.provider,
      'model_id': instance.modelId,
      'is_default': instance.isDefault,
    };

SummaryModelsResponse _$SummaryModelsResponseFromJson(
  Map<String, dynamic> json,
) => SummaryModelsResponse(
  models: (json['models'] as List<dynamic>)
      .map((e) => SummaryModelInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$SummaryModelsResponseToJson(
  SummaryModelsResponse instance,
) => <String, dynamic>{'models': instance.models, 'total': instance.total};
