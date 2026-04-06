import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_highlight_model.g.dart';

/// 高光响应模型
@JsonSerializable()
class HighlightResponse extends Equatable {

  const HighlightResponse({
    required this.id,
    required this.episodeId,
    required this.episodeTitle,
    required this.originalText, required this.insightScore, required this.noveltyScore, required this.actionabilityScore, required this.overallScore, required this.createdAt, this.subscriptionTitle,
    this.contextBefore,
    this.contextAfter,
    this.speakerHint,
    this.timestampHint,
    this.topicTags = const [],
    this.isUserFavorited = false,
  });

  factory HighlightResponse.fromJson(Map<String, dynamic> json) =>
      _$HighlightResponseFromJson(json);
  final int id;
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'episode_title')
  final String episodeTitle;
  @JsonKey(name: 'subscription_title')
  final String? subscriptionTitle;
  @JsonKey(name: 'original_text')
  final String originalText;
  @JsonKey(name: 'context_before')
  final String? contextBefore;
  @JsonKey(name: 'context_after')
  final String? contextAfter;
  @JsonKey(name: 'insight_score')
  final double insightScore;
  @JsonKey(name: 'novelty_score')
  final double noveltyScore;
  @JsonKey(name: 'actionability_score')
  final double actionabilityScore;
  @JsonKey(name: 'overall_score')
  final double overallScore;
  @JsonKey(name: 'speaker_hint')
  final String? speakerHint;
  @JsonKey(name: 'timestamp_hint')
  final String? timestampHint;
  @JsonKey(name: 'topic_tags')
  final List<String> topicTags;
  @JsonKey(name: 'is_user_favorited')
  final bool isUserFavorited;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$HighlightResponseToJson(this);

  HighlightResponse copyWith({
    int? id,
    int? episodeId,
    String? episodeTitle,
    String? subscriptionTitle,
    String? originalText,
    String? contextBefore,
    String? contextAfter,
    double? insightScore,
    double? noveltyScore,
    double? actionabilityScore,
    double? overallScore,
    String? speakerHint,
    String? timestampHint,
    List<String>? topicTags,
    bool? isUserFavorited,
    DateTime? createdAt,
  }) {
    return HighlightResponse(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      subscriptionTitle: subscriptionTitle ?? this.subscriptionTitle,
      originalText: originalText ?? this.originalText,
      contextBefore: contextBefore ?? this.contextBefore,
      contextAfter: contextAfter ?? this.contextAfter,
      insightScore: insightScore ?? this.insightScore,
      noveltyScore: noveltyScore ?? this.noveltyScore,
      actionabilityScore: actionabilityScore ?? this.actionabilityScore,
      overallScore: overallScore ?? this.overallScore,
      speakerHint: speakerHint ?? this.speakerHint,
      timestampHint: timestampHint ?? this.timestampHint,
      topicTags: topicTags ?? this.topicTags,
      isUserFavorited: isUserFavorited ?? this.isUserFavorited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        episodeId,
        episodeTitle,
        subscriptionTitle,
        originalText,
        contextBefore,
        contextAfter,
        insightScore,
        noveltyScore,
        actionabilityScore,
        overallScore,
        speakerHint,
        timestampHint,
        topicTags,
        isUserFavorited,
        createdAt,
      ];
}

/// 高光列表响应
@JsonSerializable()
class HighlightsListResponse extends Equatable {

  const HighlightsListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory HighlightsListResponse.fromJson(Map<String, dynamic> json) =>
      _$HighlightsListResponseFromJson(json);
  final List<HighlightResponse> items;
  final int total;
  final int page;
  @JsonKey(name: 'size')
  final int size;
  @JsonKey(name: 'pages')
  final int pages;

  bool get hasMore => page < pages;

  Map<String, dynamic> toJson() => _$HighlightsListResponseToJson(this);

  @override
  List<Object?> get props => [items, total, page, size, pages];
}

/// 高光日期响应
@JsonSerializable()
class HighlightDatesResponse extends Equatable {

  const HighlightDatesResponse({
    required this.dates,
  });

  factory HighlightDatesResponse.fromJson(Map<String, dynamic> json) =>
      _$HighlightDatesResponseFromJson(json);
  final List<DateTime> dates;

  Map<String, dynamic> toJson() => _$HighlightDatesResponseToJson(this);

  @override
  List<Object?> get props => [dates];
}

/// 高光统计响应
@JsonSerializable()
class HighlightStatsResponse extends Equatable {

  const HighlightStatsResponse({
    required this.totalHighlights,
    required this.avgScore,
    this.latestExtractionDate,
  });

  factory HighlightStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$HighlightStatsResponseFromJson(json);
  @JsonKey(name: 'total_highlights')
  final int totalHighlights;
  @JsonKey(name: 'avg_score')
  final double avgScore;
  @JsonKey(name: 'latest_extraction_date')
  final DateTime? latestExtractionDate;

  Map<String, dynamic> toJson() => _$HighlightStatsResponseToJson(this);

  @override
  List<Object?> get props => [totalHighlights, avgScore, latestExtractionDate];
}

/// 高光提取响应
@JsonSerializable()
class HighlightExtractResponse extends Equatable {

  const HighlightExtractResponse({
    required this.taskId,
    required this.status,
  });

  factory HighlightExtractResponse.fromJson(Map<String, dynamic> json) =>
      _$HighlightExtractResponseFromJson(json);
  @JsonKey(name: 'task_id')
  final String taskId;
  final String status;

  Map<String, dynamic> toJson() => _$HighlightExtractResponseToJson(this);

  @override
  List<Object?> get props => [taskId, status];
}
