import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:personal_ai_assistant/features/podcast/data/models/category_model.dart';

part 'podcast_subscription_model.g.dart';

@JsonSerializable()
class PodcastSubscriptionModel extends Equatable {

  const PodcastSubscriptionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.sourceUrl, required this.status, required this.fetchInterval, required this.createdAt, this.description,
    this.lastFetchedAt,
    this.errorMessage,
    this.episodeCount = 0,
    this.unplayedCount = 0,
    this.latestEpisode,
    this.categories,
    this.imageUrl,
    this.author,
    this.platform,
    this.updateFrequency,
    this.updateTime,
    this.updateDayOfWeek,
    this.nextUpdateAt,
    this.updatedAt,
  });

  factory PodcastSubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$PodcastSubscriptionModelFromJson(json);
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  final String title;
  final String? description;
  @JsonKey(name: 'source_url')
  final String sourceUrl;
  final String status;
  @JsonKey(name: 'last_fetched_at')
  final DateTime? lastFetchedAt;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'fetch_interval')
  final int fetchInterval;
  @JsonKey(name: 'episode_count')
  final int episodeCount;
  @JsonKey(name: 'unplayed_count')
  final int unplayedCount;
  @JsonKey(name: 'latest_episode')
  final Map<String, dynamic>? latestEpisode;
  final List<Category>? categories;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final String? author;
  final String? platform;
  @JsonKey(name: 'update_frequency')
  final String? updateFrequency;
  @JsonKey(name: 'update_time')
  final String? updateTime;
  @JsonKey(name: 'update_day_of_week')
  final int? updateDayOfWeek;
  @JsonKey(name: 'next_update_at')
  final DateTime? nextUpdateAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$PodcastSubscriptionModelToJson(this);

  PodcastSubscriptionModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    String? sourceUrl,
    String? status,
    DateTime? lastFetchedAt,
    String? errorMessage,
    int? fetchInterval,
    int? episodeCount,
    int? unplayedCount,
    Map<String, dynamic>? latestEpisode,
    List<Category>? categories,
    String? imageUrl,
    String? author,
    String? platform,
    String? updateFrequency,
    String? updateTime,
    int? updateDayOfWeek,
    DateTime? nextUpdateAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PodcastSubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      fetchInterval: fetchInterval ?? this.fetchInterval,
      episodeCount: episodeCount ?? this.episodeCount,
      unplayedCount: unplayedCount ?? this.unplayedCount,
      latestEpisode: latestEpisode ?? this.latestEpisode,
      categories: categories ?? this.categories,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      platform: platform ?? this.platform,
      updateFrequency: updateFrequency ?? this.updateFrequency,
      updateTime: updateTime ?? this.updateTime,
      updateDayOfWeek: updateDayOfWeek ?? this.updateDayOfWeek,
      nextUpdateAt: nextUpdateAt ?? this.nextUpdateAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        sourceUrl,
        status,
        lastFetchedAt,
        errorMessage,
        fetchInterval,
        episodeCount,
        unplayedCount,
        latestEpisode,
        categories,
        imageUrl,
        author,
        platform,
        updateFrequency,
        updateTime,
        updateDayOfWeek,
        nextUpdateAt,
        createdAt,
        updatedAt,
      ];
}

@JsonSerializable()
class PodcastSubscriptionListResponse extends Equatable {

  const PodcastSubscriptionListResponse({
    required this.subscriptions,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory PodcastSubscriptionListResponse.fromJson(Map<String, dynamic> json) {
    if (json['subscriptions'] == null) {
      final items = json['items'] ?? json['data'];
      if (items is List) {
        json = {
          ...json,
          'subscriptions': items,
        };
      }
    }
    return _$PodcastSubscriptionListResponseFromJson(json);
  }
  final List<PodcastSubscriptionModel> subscriptions;
  final int total;
  final int page;
  final int size;
  final int pages;

  Map<String, dynamic> toJson() => _$PodcastSubscriptionListResponseToJson(this);

  @override
  List<Object?> get props => [subscriptions, total, page, size, pages];
}

@JsonSerializable()
class PodcastSubscriptionCreateRequest extends Equatable {

  const PodcastSubscriptionCreateRequest({
    required this.feedUrl,
    this.categoryIds,
  });
  @JsonKey(name: 'feed_url')
  final String feedUrl;
  @JsonKey(name: 'category_ids')
  final List<int>? categoryIds;

  Map<String, dynamic> toJson() => _$PodcastSubscriptionCreateRequestToJson(this);

  @override
  List<Object?> get props => [feedUrl, categoryIds];
}

@JsonSerializable()
class ReparseResponse extends Equatable {

  const ReparseResponse({
    required this.success,
    required this.result,
  });

  factory ReparseResponse.fromJson(Map<String, dynamic> json) =>
      _$ReparseResponseFromJson(json);
  @JsonKey(defaultValue: false)
  final bool success;
  final Map<String, dynamic> result;

  Map<String, dynamic> toJson() => _$ReparseResponseToJson(this);

  @override
  List<Object?> get props => [success, result];
}

@JsonSerializable()
class SimpleResponse extends Equatable {

  const SimpleResponse({
    required this.data,
  });

  factory SimpleResponse.fromJson(Map<String, dynamic> json) =>
      _$SimpleResponseFromJson(json);
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => _$SimpleResponseToJson(this);

  @override
  List<Object?> get props => [data];
}

@JsonSerializable()
class PodcastSubscriptionBulkDeleteRequest extends Equatable {

  const PodcastSubscriptionBulkDeleteRequest({
    required this.subscriptionIds,
  });

  factory PodcastSubscriptionBulkDeleteRequest.fromJson(Map<String, dynamic> json) =>
      _$PodcastSubscriptionBulkDeleteRequestFromJson(json);
  @JsonKey(name: 'subscription_ids')
  final List<int> subscriptionIds;

  Map<String, dynamic> toJson() => _$PodcastSubscriptionBulkDeleteRequestToJson(this);

  @override
  List<Object?> get props => [subscriptionIds];
}

@JsonSerializable()
class PodcastSubscriptionBulkDeleteResponse extends Equatable {

  const PodcastSubscriptionBulkDeleteResponse({
    required this.successCount,
    required this.failedCount,
    this.errors = const [],
    this.deletedSubscriptionIds = const [],
  });

  factory PodcastSubscriptionBulkDeleteResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastSubscriptionBulkDeleteResponseFromJson(json);
  @JsonKey(name: 'success_count')
  final int successCount;
  @JsonKey(name: 'failed_count')
  final int failedCount;
  final List<Map<String, dynamic>> errors;
  @JsonKey(name: 'deleted_subscription_ids')
  final List<int> deletedSubscriptionIds;

  Map<String, dynamic> toJson() => _$PodcastSubscriptionBulkDeleteResponseToJson(this);

  @override
  List<Object?> get props => [successCount, failedCount, errors, deletedSubscriptionIds];
}
