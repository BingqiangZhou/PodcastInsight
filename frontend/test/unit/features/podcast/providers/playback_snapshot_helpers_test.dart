import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/playback_progress_policy.dart';

void main() {
  group('playback snapshot storage key', () {
    test('isolates keys by user id', () {
      final keyA = playbackSnapshotStorageKeyForUser('1001');
      final keyB = playbackSnapshotStorageKeyForUser('1002');

      expect(keyA, 'podcast_last_playback_snapshot_v1_1001');
      expect(keyB, 'podcast_last_playback_snapshot_v1_1002');
      expect(keyA, isNot(equals(keyB)));
    });
  });

  group('resolveCompletedPositionMs', () {
    test('prefers duration when duration is available', () {
      final result = resolveCompletedPositionMs(123000, 1800000);
      expect(result, 1800000);
    });

    test('falls back to current position when duration is unknown', () {
      final result = resolveCompletedPositionMs(123000, 0);
      expect(result, 123000);
    });

    test('clamps negative position to zero when duration is unknown', () {
      final result = resolveCompletedPositionMs(-1000, 0);
      expect(result, 0);
    });

    test('completed payload persists tail position instead of zero', () {
      final completedMs = resolveCompletedPositionMs(1000, 1800000);
      final payload = buildPersistPayload(completedMs, 1800000, false);

      expect(payload.positionSec, 1800);
      expect(payload.positionSec, isNot(0));
    });
  });
}
