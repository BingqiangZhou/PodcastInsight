import 'package:equatable/equatable.dart';

class ProfileStatsModel extends Equatable {

  const ProfileStatsModel({
    required this.totalSubscriptions,
    required this.totalEpisodes,
    required this.summariesGenerated,
    required this.pendingSummaries,
    required this.playedEpisodes,
    this.latestDailyReportDate,
    this.totalHighlights = 0,
  });

  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatsModel(
      totalSubscriptions: (json['total_subscriptions'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      summariesGenerated: (json['summaries_generated'] as num?)?.toInt() ?? 0,
      pendingSummaries: (json['pending_summaries'] as num?)?.toInt() ?? 0,
      playedEpisodes: (json['played_episodes'] as num?)?.toInt() ?? 0,
      latestDailyReportDate: json['latest_daily_report_date'] as String?,
      totalHighlights: (json['total_highlights'] as num?)?.toInt() ?? 0,
    );
  }
  final int totalSubscriptions;
  final int totalEpisodes;
  final int summariesGenerated;
  final int pendingSummaries;
  final int playedEpisodes;
  final String? latestDailyReportDate;
  final int totalHighlights;

  @override
  List<Object?> get props => [
    totalSubscriptions,
    totalEpisodes,
    summariesGenerated,
    pendingSummaries,
    playedEpisodes,
    latestDailyReportDate,
    totalHighlights,
  ];
}
