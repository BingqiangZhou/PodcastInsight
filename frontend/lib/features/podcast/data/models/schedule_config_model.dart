import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../../core/utils/app_logger.dart' as logger;

part 'schedule_config_model.g.dart';

/// Update frequency enum for scheduled RSS feed refresh
enum UpdateFrequency {
  @JsonValue('HOURLY')
  hourly,
  @JsonValue('DAILY')
  daily,
  @JsonValue('WEEKLY')
  weekly;

  String get value {
    switch (this) {
      case UpdateFrequency.hourly:
        return 'HOURLY';
      case UpdateFrequency.daily:
        return 'DAILY';
      case UpdateFrequency.weekly:
        return 'WEEKLY';
    }
  }

  String get displayName {
    switch (this) {
      case UpdateFrequency.hourly:
        return 'Hourly';
      case UpdateFrequency.daily:
        return 'Daily';
      case UpdateFrequency.weekly:
        return 'Weekly';
    }
  }
}

/// Schedule configuration update request
@JsonSerializable()
class ScheduleConfigUpdateRequest extends Equatable {
  @JsonKey(name: 'update_frequency')
  final String updateFrequency;
  @JsonKey(name: 'update_time')
  final String? updateTime;
  @JsonKey(name: 'update_day_of_week')
  final int? updateDayOfWeek;
  @JsonKey(name: 'fetch_interval')
  final int? fetchInterval;

  const ScheduleConfigUpdateRequest({
    required this.updateFrequency,
    this.updateTime,
    this.updateDayOfWeek,
    this.fetchInterval,
  });

  factory ScheduleConfigUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ScheduleConfigUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleConfigUpdateRequestToJson(this);

  @override
  List<Object?> get props => [
        updateFrequency,
        updateTime,
        updateDayOfWeek,
        fetchInterval,
      ];
}

/// Schedule configuration response
@JsonSerializable()
class ScheduleConfigResponse extends Equatable {
  final int id;
  final String title;
  @JsonKey(name: 'update_frequency')
  final String updateFrequency;
  @JsonKey(name: 'update_time')
  final String? updateTime;
  @JsonKey(name: 'update_day_of_week')
  final int? updateDayOfWeek;
  @JsonKey(name: 'fetch_interval')
  final int? fetchInterval;
  @JsonKey(name: 'next_update_at')
  final DateTime? nextUpdateAt;
  @JsonKey(name: 'last_updated_at')
  final DateTime? lastUpdatedAt;

  const ScheduleConfigResponse({
    required this.id,
    required this.title,
    required this.updateFrequency,
    this.updateTime,
    this.updateDayOfWeek,
    this.fetchInterval,
    this.nextUpdateAt,
    this.lastUpdatedAt,
  });

  factory ScheduleConfigResponse.fromJson(Map<String, dynamic> json) =>
      _$ScheduleConfigResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleConfigResponseToJson(this);

  /// Get the frequency enum from the string value
  UpdateFrequency? get frequency {
    try {
      return UpdateFrequency.values.firstWhere(
        (e) => e.value == updateFrequency,
      );
    } catch (e) {
      logger.AppLogger.debug('[ScheduleConfig] Unknown update frequency: $updateFrequency, error: $e');
      return null;
    }
  }

  /// Get display text for next update time
  String? get nextUpdateDisplay {
    if (nextUpdateAt == null) return null;

    // Convert UTC to local time for display
    final localTime = nextUpdateAt!.toLocal();

    // Format: 2025-01-15 14:30
    final year = localTime.year;
    final month = localTime.month.toString().padLeft(2, '0');
    final day = localTime.day.toString().padLeft(2, '0');
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    final second = localTime.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        updateFrequency,
        updateTime,
        updateDayOfWeek,
        fetchInterval,
        nextUpdateAt,
        lastUpdatedAt,
      ];
}
