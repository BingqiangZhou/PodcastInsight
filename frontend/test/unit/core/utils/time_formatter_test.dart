import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter - UTC to Local Conversion Tests', () {
    test('parseUtcTime should convert UTC time string to local DateTime', () {
      // 模拟 API 返回的 UTC 时间字符串（带 +00:00 时区）
      const utcTimeString = '2025-12-26T14:16:36+00:00';
      final result = TimeFormatter.parseUtcTime(utcTimeString);

      // 解析后的 DateTime 应该转换为本地时间
      // 注意：isUtc 应该是 false（表示本地时间）
      expect(result.isUtc, false);
    });

    test('toLocalTime should convert UTC DateTime to local', () {
      // 创建一个 UTC DateTime
      final utcDateTime = DateTime.parse('2025-12-26T14:16:36Z');
      expect(utcDateTime.isUtc, true);

      // 转换为本地时间
      final localDateTime = TimeFormatter.toLocalTime(utcDateTime);
      expect(localDateTime.isUtc, false);
    });

    test('toLocalTime should keep local DateTime unchanged', () {
      // 创建一个本地 DateTime（不带时区信息）
      final localDateTime = DateTime(2025, 12, 26, 14, 16, 36);
      expect(localDateTime.isUtc, false);

      // 应该保持不变
      final result = TimeFormatter.toLocalTime(localDateTime);
      expect(result.isUtc, false);
      expect(result, localDateTime);
    });

    test('formatRelativeTime should work with UTC DateTime input', () {
      // 创建一个 1 小时前的 UTC DateTime
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1)).toUtc();

      // 格式化相对时间
      final result = TimeFormatter.formatRelativeTime(oneHourAgo);

      // 应该显示 "1小时前"（而不是错误的时间差）
      expect(result, contains('小时前'));
    });

    test('formatFullDateTime should convert UTC to local', () {
      // 创建一个 UTC 时间字符串
      const utcTimeString = '2025-12-26T14:16:36+00:00';

      final result = TimeFormatter.formatFullDateTime(utcTimeString);

      // 结果应该是一个格式化的日期时间字符串
      expect(result, isNotEmpty);
      expect(result, contains(RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}')));
    });

    test('formatShortDate should convert UTC to local', () {
      const utcTimeString = '2025-12-26T14:16:36+00:00';
      final result = TimeFormatter.formatShortDate(utcTimeString);

      expect(result, isNotEmpty);
      expect(result, contains(RegExp(r'\d{2}-\d{2}')));
    });

    test('formatTime should convert UTC to local', () {
      const utcTimeString = '2025-12-26T14:16:36+00:00';
      final result = TimeFormatter.formatTime(utcTimeString);

      expect(result, isNotEmpty);
      expect(result, contains(RegExp(r'\d{2}:\d{2}')));
    });

    test('formatDuration should return mm:ss when duration is under one hour', () {
      final result = TimeFormatter.formatDuration(
        const Duration(minutes: 7, seconds: 5),
      );

      expect(result, '07:05');
    });

    test('formatDuration should return hh:mm:ss when duration is one hour or more', () {
      final result = TimeFormatter.formatDuration(
        const Duration(hours: 2, minutes: 3, seconds: 4),
      );

      expect(result, '02:03:04');
    });

    test('formatSecondsClock should clamp negative values to zero', () {
      final result = TimeFormatter.formatSecondsClock(-5);

      expect(result, '00:00');
    });

    test('formatSecondsClock should support unpadded hour display', () {
      final result = TimeFormatter.formatSecondsClock(
        3725,
        padHours: false,
      );

      expect(result, '1:02:05');
    });
  });
}
