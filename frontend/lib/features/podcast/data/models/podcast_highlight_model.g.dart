// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_highlight_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HighlightResponse _$HighlightResponseFromJson(Map<String, dynamic> json) =>
    HighlightResponse(
      id: (json['id'] as num).toInt(),
      episodeId: (json['episode_id'] as num).toInt(),
      episodeTitle: json['episode_title'] as String,
      subscriptionTitle: json['subscription_title'] as String?,
      originalText: json['original_text'] as String,
      contextBefore: json['context_before'] as String?,
      contextAfter: json['context_after'] as String?,
      insightScore: (json['insight_score'] as num).toDouble(),
      noveltyScore: (json['novelty_score'] as num).toDouble(),
      actionabilityScore: (json['actionability_score'] as num).toDouble(),
      overallScore: (json['overall_score'] as num).toDouble(),
      speakerHint: json['speaker_hint'] as String?,
      timestampHint: json['timestamp_hint'] as String?,
      topicTags:
          (json['topic_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isUserFavorited: json['is_user_favorited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$HighlightResponseToJson(HighlightResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'episode_id': instance.episodeId,
      'episode_title': instance.episodeTitle,
      'subscription_title': instance.subscriptionTitle,
      'original_text': instance.originalText,
      'context_before': instance.contextBefore,
      'context_after': instance.contextAfter,
      'insight_score': instance.insightScore,
      'novelty_score': instance.noveltyScore,
      'actionability_score': instance.actionabilityScore,
      'overall_score': instance.overallScore,
      'speaker_hint': instance.speakerHint,
      'timestamp_hint': instance.timestampHint,
      'topic_tags': instance.topicTags,
      'is_user_favorited': instance.isUserFavorited,
      'created_at': instance.createdAt.toIso8601String(),
    };

HighlightsListResponse _$HighlightsListResponseFromJson(
  Map<String, dynamic> json,
) => HighlightsListResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => HighlightResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  perPage: (json['per_page'] as num).toInt(),
  hasMore: json['has_more'] as bool,
);

Map<String, dynamic> _$HighlightsListResponseToJson(
  HighlightsListResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'total': instance.total,
  'page': instance.page,
  'per_page': instance.perPage,
  'has_more': instance.hasMore,
};

HighlightDatesResponse _$HighlightDatesResponseFromJson(
  Map<String, dynamic> json,
) => HighlightDatesResponse(
  dates: (json['dates'] as List<dynamic>)
      .map((e) => DateTime.parse(e as String))
      .toList(),
);

Map<String, dynamic> _$HighlightDatesResponseToJson(
  HighlightDatesResponse instance,
) => <String, dynamic>{
  'dates': instance.dates.map((e) => e.toIso8601String()).toList(),
};

HighlightStatsResponse _$HighlightStatsResponseFromJson(
  Map<String, dynamic> json,
) => HighlightStatsResponse(
  totalHighlights: (json['total_highlights'] as num).toInt(),
  avgScore: (json['avg_score'] as num).toDouble(),
  latestExtractionDate: json['latest_extraction_date'] == null
      ? null
      : DateTime.parse(json['latest_extraction_date'] as String),
);

Map<String, dynamic> _$HighlightStatsResponseToJson(
  HighlightStatsResponse instance,
) => <String, dynamic>{
  'total_highlights': instance.totalHighlights,
  'avg_score': instance.avgScore,
  'latest_extraction_date': instance.latestExtractionDate?.toIso8601String(),
};

HighlightExtractResponse _$HighlightExtractResponseFromJson(
  Map<String, dynamic> json,
) => HighlightExtractResponse(
  taskId: json['task_id'] as String,
  status: json['status'] as String,
);

Map<String, dynamic> _$HighlightExtractResponseToJson(
  HighlightExtractResponse instance,
) => <String, dynamic>{'task_id': instance.taskId, 'status': instance.status};
