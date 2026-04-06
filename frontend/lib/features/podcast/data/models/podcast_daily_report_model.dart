import 'package:equatable/equatable.dart';

import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

DateTime? _parseDateOnly(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

class PodcastDailyReportItem extends Equatable {

  const PodcastDailyReportItem({
    required this.episodeId,
    required this.subscriptionId,
    required this.episodeTitle,
    required this.oneLineSummary, required this.isCarryover, required this.episodeCreatedAt, this.subscriptionTitle,
    this.episodePublishedAt,
  });

  factory PodcastDailyReportItem.fromJson(Map<String, dynamic> json) {
    return PodcastDailyReportItem(
      episodeId: json['episode_id'] as int,
      subscriptionId: json['subscription_id'] as int,
      episodeTitle: json['episode_title'] as String? ?? '',
      subscriptionTitle: json['subscription_title'] as String?,
      oneLineSummary: json['one_line_summary'] as String? ?? '',
      isCarryover: json['is_carryover'] as bool? ?? false,
      episodeCreatedAt: DateTime.parse(json['episode_created_at'] as String),
      episodePublishedAt: json['episode_published_at'] == null
          ? null
          : DateTime.parse(json['episode_published_at'] as String),
    );
  }
  final int episodeId;
  final int subscriptionId;
  final String episodeTitle;
  final String? subscriptionTitle;
  final String oneLineSummary;
  final bool isCarryover;
  final DateTime episodeCreatedAt;
  final DateTime? episodePublishedAt;

  Map<String, dynamic> toJson() {
    return {
      'episode_id': episodeId,
      'subscription_id': subscriptionId,
      'episode_title': episodeTitle,
      'subscription_title': subscriptionTitle,
      'one_line_summary': oneLineSummary,
      'is_carryover': isCarryover,
      'episode_created_at': episodeCreatedAt.toIso8601String(),
      'episode_published_at': episodePublishedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    episodeId,
    subscriptionId,
    episodeTitle,
    subscriptionTitle,
    oneLineSummary,
    isCarryover,
    episodeCreatedAt,
    episodePublishedAt,
  ];
}

class PodcastDailyReportResponse extends Equatable {

  const PodcastDailyReportResponse({
    required this.available,
    required this.timezone, required this.scheduleTimeLocal, required this.totalItems, required this.items, this.reportDate,
    this.generatedAt,
  });

  factory PodcastDailyReportResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return PodcastDailyReportResponse(
      available: json['available'] as bool? ?? false,
      reportDate: _parseDateOnly(json['report_date'] as String?),
      timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
      scheduleTimeLocal: json['schedule_time_local'] as String? ?? '03:30',
      generatedAt: json['generated_at'] == null
          ? null
          : DateTime.parse(json['generated_at'] as String),
      totalItems: json['total_items'] as int? ?? 0,
      items: rawItems
          .map(
            (e) => PodcastDailyReportItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
  final bool available;
  final DateTime? reportDate;
  final String timezone;
  final String scheduleTimeLocal;
  final DateTime? generatedAt;
  final int totalItems;
  final List<PodcastDailyReportItem> items;

  Map<String, dynamic> toJson() {
    return {
      'available': available,
      'report_date': reportDate != null ? TimeFormatter.formatDate(reportDate) : null,
      'timezone': timezone,
      'schedule_time_local': scheduleTimeLocal,
      'generated_at': generatedAt?.toIso8601String(),
      'total_items': totalItems,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    available,
    reportDate,
    timezone,
    scheduleTimeLocal,
    generatedAt,
    totalItems,
    items,
  ];
}

class PodcastDailyReportDateItem extends Equatable {

  const PodcastDailyReportDateItem({
    required this.reportDate,
    required this.totalItems,
    this.generatedAt,
  });

  factory PodcastDailyReportDateItem.fromJson(Map<String, dynamic> json) {
    return PodcastDailyReportDateItem(
      reportDate:
          _parseDateOnly(json['report_date'] as String?) ??
          DateTime(1970),
      totalItems: json['total_items'] as int? ?? 0,
      generatedAt: json['generated_at'] == null
          ? null
          : DateTime.parse(json['generated_at'] as String),
    );
  }
  final DateTime reportDate;
  final int totalItems;
  final DateTime? generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'report_date': TimeFormatter.formatDate(reportDate),
      'total_items': totalItems,
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [reportDate, totalItems, generatedAt];
}

class PodcastDailyReportDatesResponse extends Equatable {

  const PodcastDailyReportDatesResponse({
    required this.dates,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory PodcastDailyReportDatesResponse.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'] as List<dynamic>? ?? const [];
    return PodcastDailyReportDatesResponse(
      dates: rawDates
          .map(
            (e) =>
                PodcastDailyReportDateItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      size: json['size'] as int? ?? 30,
      pages: json['pages'] as int? ?? 0,
    );
  }
  final List<PodcastDailyReportDateItem> dates;
  final int total;
  final int page;
  final int size;
  final int pages;

  Map<String, dynamic> toJson() {
    return {
      'dates': dates.map((e) => e.toJson()).toList(),
      'total': total,
      'page': page,
      'size': size,
      'pages': pages,
    };
  }

  @override
  List<Object?> get props => [dates, total, page, size, pages];
}
