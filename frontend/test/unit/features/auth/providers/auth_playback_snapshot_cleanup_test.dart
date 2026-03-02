import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('playbackSnapshotKeysToClearOnLogout', () {
    test('returns legacy + user scoped key when user id exists', () {
      final keys = playbackSnapshotKeysToClearOnLogout('42');

      expect(keys, <String>[
        'podcast_last_playback_snapshot_v1',
        'podcast_last_playback_snapshot_v1_42',
      ]);
    });

    test('returns only legacy key when user id is empty', () {
      final keys = playbackSnapshotKeysToClearOnLogout('');
      expect(keys, <String>['podcast_last_playback_snapshot_v1']);
    });
  });
}
