import 'package:equatable/equatable.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

class PlaybackHistoryLiteItem extends Equatable {

  const PlaybackHistoryLiteItem({
    required this.id,
    required this.subscriptionId,
    required this.title, required this.publishedAt, this.subscriptionTitle,
    this.subscriptionImageUrl,
    this.imageUrl,
    this.audioDuration,
    this.playbackPosition,
    this.lastPlayedAt,
  });

  factory PlaybackHistoryLiteItem.fromJson(Map<String, dynamic> json) {
    return PlaybackHistoryLiteItem(
      id: (json['id'] as num).toInt(),
      subscriptionId: (json['subscription_id'] as num?)?.toInt() ?? 0,
      subscriptionTitle: json['subscription_title'] as String?,
      subscriptionImageUrl: json['subscription_image_url'] as String?,
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      audioDuration: (json['audio_duration'] as num?)?.toInt(),
      playbackPosition: (json['playback_position'] as num?)?.toInt(),
      lastPlayedAt: json['last_played_at'] != null
          ? DateTime.tryParse(json['last_played_at'] as String)
          : null,
      publishedAt:
          DateTime.tryParse(json['published_at'] as String) ?? DateTime(1970),
    );
  }
  final int id;
  final int subscriptionId;
  final String? subscriptionTitle;
  final String? subscriptionImageUrl;
  final String title;
  final String? imageUrl;
  final int? audioDuration;
  final int? playbackPosition;
  final DateTime? lastPlayedAt;
  final DateTime publishedAt;

  String get formattedDuration {
    final duration = audioDuration;
    if (duration == null) return '--:--';
    return TimeFormatter.formatDuration(Duration(seconds: duration));
  }

  @override
  List<Object?> get props => [
    id,
    subscriptionId,
    subscriptionTitle,
    subscriptionImageUrl,
    title,
    imageUrl,
    audioDuration,
    playbackPosition,
    lastPlayedAt,
    publishedAt,
  ];
}

class PlaybackHistoryLiteResponse extends Equatable {

  const PlaybackHistoryLiteResponse({
    required this.episodes,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory PlaybackHistoryLiteResponse.fromJson(Map<String, dynamic> json) {
    final episodesJson = json['episodes'] as List<dynamic>? ?? const [];
    return PlaybackHistoryLiteResponse(
      episodes: episodesJson
          .map(
            (item) =>
                PlaybackHistoryLiteItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
      pages: (json['pages'] as num?)?.toInt() ?? 0,
    );
  }
  final List<PlaybackHistoryLiteItem> episodes;
  final int total;
  final int page;
  final int size;
  final int pages;

  @override
  List<Object?> get props => [episodes, total, page, size, pages];
}
