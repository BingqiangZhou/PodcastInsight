import 'package:equatable/equatable.dart';

import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';

class PodcastQueueItemModel extends Equatable {

  const PodcastQueueItemModel({
    required this.episodeId,
    required this.position,
    required this.title, required this.podcastId, required this.audioUrl, this.playbackPosition,
    this.duration,
    this.publishedAt,
    this.imageUrl,
    this.subscriptionTitle,
    this.subscriptionImageUrl,
  });

  factory PodcastQueueItemModel.fromJson(Map<String, dynamic> json) {
    return PodcastQueueItemModel(
      episodeId: json['episode_id'] as int,
      position: json['position'] as int,
      playbackPosition: json['playback_position'] as int?,
      title: json['title'] as String? ?? '',
      podcastId: json['podcast_id'] as int? ?? 0,
      audioUrl: json['audio_url'] as String? ?? '',
      duration: json['duration'] as int?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      imageUrl: json['image_url'] as String?,
      subscriptionTitle: json['subscription_title'] as String?,
      subscriptionImageUrl: json['subscription_image_url'] as String?,
    );
  }
  final int episodeId;
  final int position;
  final int? playbackPosition;
  final String title;
  final int podcastId;
  final String audioUrl;
  final int? duration;
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? subscriptionTitle;
  final String? subscriptionImageUrl;

  Map<String, dynamic> toJson() {
    return {
      'episode_id': episodeId,
      'position': position,
      'playback_position': playbackPosition,
      'title': title,
      'podcast_id': podcastId,
      'audio_url': audioUrl,
      'duration': duration,
      'published_at': publishedAt?.toIso8601String(),
      'image_url': imageUrl,
      'subscription_title': subscriptionTitle,
      'subscription_image_url': subscriptionImageUrl,
    };
  }

  PodcastEpisodeModel toEpisodeModel() {
    final now = DateTime.now();
    return PodcastEpisodeModel(
      id: episodeId,
      subscriptionId: podcastId,
      subscriptionImageUrl: subscriptionImageUrl,
      title: title,
      subscriptionTitle: subscriptionTitle,
      audioUrl: audioUrl,
      audioDuration: duration,
      playbackPosition: playbackPosition,
      publishedAt: publishedAt ?? now,
      imageUrl: imageUrl,
      createdAt: now,
    );
  }

  @override
  List<Object?> get props => [
    episodeId,
    position,
    playbackPosition,
    title,
    podcastId,
    audioUrl,
    duration,
    publishedAt,
    imageUrl,
    subscriptionTitle,
    subscriptionImageUrl,
  ];
}

class PodcastQueueModel extends Equatable {

  const PodcastQueueModel({
    this.currentEpisodeId,
    this.revision = 0,
    this.updatedAt,
    this.items = const [],
  });

  factory PodcastQueueModel.empty() => const PodcastQueueModel();

  factory PodcastQueueModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return PodcastQueueModel(
      currentEpisodeId: json['current_episode_id'] as int?,
      revision: json['revision'] as int? ?? 0,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      items: rawItems
          .map(
            (item) =>
                PodcastQueueItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
  final int? currentEpisodeId;
  final int revision;
  final DateTime? updatedAt;
  final List<PodcastQueueItemModel> items;

  Map<String, dynamic> toJson() {
    return {
      'current_episode_id': currentEpisodeId,
      'revision': revision,
      'updated_at': updatedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  PodcastQueueItemModel? get currentItem {
    if (currentEpisodeId == null) {
      return null;
    }
    for (final item in items) {
      if (item.episodeId == currentEpisodeId) {
        return item;
      }
    }
    return null;
  }

  PodcastQueueModel copyWith({
    int? currentEpisodeId,
    int? revision,
    DateTime? updatedAt,
    List<PodcastQueueItemModel>? items,
  }) {
    return PodcastQueueModel(
      currentEpisodeId: currentEpisodeId ?? this.currentEpisodeId,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [currentEpisodeId, revision, updatedAt, items];
}

class PodcastQueueAddItemRequest {

  const PodcastQueueAddItemRequest({required this.episodeId});
  final int episodeId;

  Map<String, dynamic> toJson() => {'episode_id': episodeId};
}

class PodcastQueueReorderRequest {

  const PodcastQueueReorderRequest({required this.episodeIds});
  final List<int> episodeIds;

  Map<String, dynamic> toJson() => {'episode_ids': episodeIds};
}

class PodcastQueueSetCurrentRequest {

  const PodcastQueueSetCurrentRequest({required this.episodeId});
  final int episodeId;

  Map<String, dynamic> toJson() => {'episode_id': episodeId};
}

class PodcastQueueActivateRequest {

  const PodcastQueueActivateRequest({required this.episodeId});
  final int episodeId;

  Map<String, dynamic> toJson() => {'episode_id': episodeId};
}
