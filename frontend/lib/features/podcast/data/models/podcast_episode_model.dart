import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

part 'podcast_episode_model.g.dart';

@JsonSerializable()
class PodcastEpisodeModel extends Equatable {
  final int id;
  @JsonKey(name: 'subscription_id')
  final int subscriptionId;
  @JsonKey(name: 'subscription_image_url')
  final String? subscriptionImageUrl;
  final String title;
  @JsonKey(name: 'subscription_title')
  final String? subscriptionTitle;
  final String? description;
  @JsonKey(name: 'audio_url')
  final String audioUrl;
  @JsonKey(name: 'audio_duration')
  final int? audioDuration;
  @JsonKey(name: 'audio_file_size')
  final int? audioFileSize;
  @JsonKey(name: 'published_at')
  final DateTime publishedAt;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'item_link')
  final String? itemLink;
  @JsonKey(name: 'transcript_url')
  final String? transcriptUrl;
  @JsonKey(name: 'transcript_content')
  final String? transcriptContent;
  @JsonKey(name: 'ai_summary')
  final String? aiSummary;
  @JsonKey(name: 'summary_version')
  final String? summaryVersion;
  @JsonKey(name: 'ai_confidence_score')
  final double? aiConfidenceScore;
  @JsonKey(name: 'play_count')
  final int playCount;
  @JsonKey(name: 'last_played_at')
  final DateTime? lastPlayedAt;
  final int? season;
  @JsonKey(name: 'episode_number')
  final int? episodeNumber;
  final bool explicit;
  final String status;
  final Map<String, dynamic>? metadata;

  // Playback state
  @JsonKey(name: 'playback_position')
  final int? playbackPosition;
  @JsonKey(name: 'is_playing')
  final bool isPlaying;
  @JsonKey(name: 'playback_rate')
  final double playbackRate;
  @JsonKey(name: 'is_played')
  final bool isPlayed;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'summary_status')
  final String? summaryStatus;
  @JsonKey(name: 'summary_error_message')
  final String? summaryErrorMessage;
  @JsonKey(name: 'summary_model_used')
  final String? summaryModelUsed;
  @JsonKey(name: 'summary_processing_time')
  final double? summaryProcessingTime;

  // Additional detail fields (from episode detail endpoint)
  final Map<String, dynamic>? subscription;
  @JsonKey(name: 'related_episodes')
  final List<dynamic>? relatedEpisodes;

  const PodcastEpisodeModel({
    required this.id,
    required this.subscriptionId,
    this.subscriptionImageUrl,
    required this.title,
    this.subscriptionTitle,
    this.description,
    required this.audioUrl,
    this.audioDuration,
    this.audioFileSize,
    required this.publishedAt,
    this.imageUrl,
    this.itemLink,
    this.transcriptUrl,
    this.transcriptContent,
    this.aiSummary,
    this.summaryVersion,
    this.aiConfidenceScore,
    this.playCount = 0,
    this.lastPlayedAt,
    this.season,
    this.episodeNumber,
    this.explicit = false,
    this.status = 'published',
    this.metadata,
    this.playbackPosition,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.isPlayed = false,
    required this.createdAt,
    this.updatedAt,
    this.summaryStatus,
    this.summaryErrorMessage,
    this.summaryModelUsed,
    this.summaryProcessingTime,
    this.subscription,
    this.relatedEpisodes,
  });

  factory PodcastEpisodeModel.fromJson(Map<String, dynamic> json) =>
      _$PodcastEpisodeModelFromJson(json);

  Map<String, dynamic> toJson() => _$PodcastEpisodeModelToJson(this);

  PodcastEpisodeModel copyWith({
    int? id,
    int? subscriptionId,
    String? subscriptionImageUrl,
    String? title,
    String? subscriptionTitle,
    String? description,
    String? audioUrl,
    int? audioDuration,
    int? audioFileSize,
    DateTime? publishedAt,
    String? imageUrl,
    String? itemLink,
    String? transcriptUrl,
    String? transcriptContent,
    String? aiSummary,
    String? summaryVersion,
    double? aiConfidenceScore,
    int? playCount,
    DateTime? lastPlayedAt,
    int? season,
    int? episodeNumber,
    bool? explicit,
    String? status,
    Map<String, dynamic>? metadata,
    int? playbackPosition,
    bool? isPlaying,
    double? playbackRate,
    bool? isPlayed,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? summaryStatus,
    String? summaryErrorMessage,
    String? summaryModelUsed,
    double? summaryProcessingTime,
    Map<String, dynamic>? subscription,
    List<dynamic>? relatedEpisodes,
  }) {
    return PodcastEpisodeModel(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      subscriptionImageUrl: subscriptionImageUrl ?? this.subscriptionImageUrl,
      title: title ?? this.title,
      subscriptionTitle: subscriptionTitle ?? this.subscriptionTitle,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      audioFileSize: audioFileSize ?? this.audioFileSize,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      itemLink: itemLink ?? this.itemLink,
      transcriptUrl: transcriptUrl ?? this.transcriptUrl,
      transcriptContent: transcriptContent ?? this.transcriptContent,
      aiSummary: aiSummary ?? this.aiSummary,
      summaryVersion: summaryVersion ?? this.summaryVersion,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      season: season ?? this.season,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      explicit: explicit ?? this.explicit,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      isPlayed: isPlayed ?? this.isPlayed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      summaryStatus: summaryStatus ?? this.summaryStatus,
      summaryErrorMessage: summaryErrorMessage ?? this.summaryErrorMessage,
      summaryModelUsed: summaryModelUsed ?? this.summaryModelUsed,
      summaryProcessingTime:
          summaryProcessingTime ?? this.summaryProcessingTime,
      subscription: subscription ?? this.subscription,
      relatedEpisodes: relatedEpisodes ?? this.relatedEpisodes,
    );
  }

  // Helper getters
  String get formattedDuration {
    final duration = audioDuration;
    if (duration == null) return '--:--';
    return TimeFormatter.formatDuration(Duration(seconds: duration));
  }

  String get formattedPlaybackPosition {
    final position = playbackPosition;
    if (position == null) return '00:00';
    return TimeFormatter.formatDuration(Duration(seconds: position));
  }

  double get progressPercentage {
    final duration = audioDuration;
    final position = playbackPosition;
    if (duration == null || position == null) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  String get episodeIdentifier {
    final s = season;
    final ep = episodeNumber;
    if (s != null && ep != null) {
      return 'S${s.toString().padLeft(2, '0')}E${ep.toString().padLeft(2, '0')}';
    } else if (ep != null) {
      return 'Episode $ep';
    }
    return '';
  }

  @override
  List<Object?> get props => [
    id,
    subscriptionId,
    subscriptionImageUrl,
    title,
    subscriptionTitle,
    description,
    audioUrl,
    audioDuration,
    audioFileSize,
    publishedAt,
    imageUrl,
    itemLink,
    transcriptUrl,
    transcriptContent,
    aiSummary,
    summaryVersion,
    aiConfidenceScore,
    playCount,
    lastPlayedAt,
    season,
    episodeNumber,
    explicit,
    status,
    metadata,
    playbackPosition,
    isPlaying,
    playbackRate,
    isPlayed,
    createdAt,
    updatedAt,
    summaryStatus,
    summaryErrorMessage,
    summaryModelUsed,
    summaryProcessingTime,
    subscription,
    relatedEpisodes,
  ];
}

@JsonSerializable()
class PodcastEpisodeListResponse extends Equatable {
  final List<PodcastEpisodeModel> episodes;
  final int total;
  final int page;
  final int size;
  final int pages;
  @JsonKey(name: 'subscription_id')
  final int subscriptionId;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  const PodcastEpisodeListResponse({
    required this.episodes,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
    required this.subscriptionId,
    this.nextCursor,
  });

  factory PodcastEpisodeListResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastEpisodeListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PodcastEpisodeListResponseToJson(this);

  @override
  List<Object?> get props => [
    episodes,
    total,
    page,
    size,
    pages,
    subscriptionId,
    nextCursor,
  ];
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PodcastFeedResponse extends Equatable {
  final List<PodcastEpisodeModel> items;
  @JsonKey(defaultValue: false)
  final bool hasMore;
  final int? nextPage;
  final String? nextCursor;
  final int total;

  const PodcastFeedResponse({
    required this.items,
    required this.hasMore,
    this.nextPage,
    this.nextCursor,
    required this.total,
  });

  factory PodcastFeedResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastFeedResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PodcastFeedResponseToJson(this);

  @override
  List<Object?> get props => [items, hasMore, nextPage, nextCursor, total];
}
