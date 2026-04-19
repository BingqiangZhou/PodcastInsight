import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/playback_dao.dart';

void main() {
  late AppDatabase db;
  late PlaybackDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = PlaybackDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  PlaybackStatesCompanion _makeState({
    required int episodeId,
    int positionSeconds = 0,
    double playbackRate = 1.0,
    int playCount = 0,
    bool isCompleted = false,
    DateTime? lastUpdatedAt,
  }) {
    return PlaybackStatesCompanion(
      episodeId: Value(episodeId),
      positionSeconds: Value(positionSeconds),
      playbackRate: Value(playbackRate),
      playCount: Value(playCount),
      isCompleted: Value(isCompleted),
      lastUpdatedAt: Value(lastUpdatedAt ?? DateTime(2025, 1, 1)),
    );
  }

  group('upsertPlaybackState & getByEpisodeId', () {
    test('inserts and retrieves a playback state', () async {
      final now = DateTime(2025, 6, 15);
      await dao.upsertPlaybackState(_makeState(
        episodeId: 1,
        positionSeconds: 120,
        playbackRate: 1.5,
        playCount: 3,
        isCompleted: false,
        lastUpdatedAt: now,
      ));

      final state = await dao.getByEpisodeId(1);

      expect(state, isNotNull);
      expect(state!.episodeId, 1);
      expect(state.positionSeconds, 120);
      expect(state.playbackRate, 1.5);
      expect(state.playCount, 3);
      expect(state.isCompleted, isFalse);
    });

    test('returns null for non-existent episode', () async {
      final state = await dao.getByEpisodeId(999);
      expect(state, isNull);
    });

    test('upserts (updates) existing state on conflict', () async {
      await dao.upsertPlaybackState(_makeState(
        episodeId: 1,
        positionSeconds: 100,
      ));

      await dao.upsertPlaybackState(_makeState(
        episodeId: 1,
        positionSeconds: 200,
        playbackRate: 2.0,
      ));

      final state = await dao.getByEpisodeId(1);
      expect(state!.positionSeconds, 200);
      expect(state.playbackRate, 2.0);
    });
  });

  group('updatePosition', () {
    test('updates position for an existing episode', () async {
      await dao.upsertPlaybackState(_makeState(
        episodeId: 1,
        positionSeconds: 50,
      ));

      await dao.updatePosition(1, 150);

      final state = await dao.getByEpisodeId(1);
      expect(state!.positionSeconds, 150);
      // lastUpdatedAt should be updated (later than original)
      expect(state.lastUpdatedAt.isAfter(DateTime(2025, 1, 1)), isTrue);
    });

    test('does nothing when no matching episode exists', () async {
      // updatePosition runs an UPDATE with a WHERE clause that matches nothing.
      // No error should be thrown.
      await dao.updatePosition(999, 100);

      final state = await dao.getByEpisodeId(999);
      expect(state, isNull);
    });
  });

  group('watchAll', () {
    test('emits playback states ordered by lastUpdatedAt descending', () async {
      await dao.upsertPlaybackState(_makeState(
        episodeId: 1,
        lastUpdatedAt: DateTime(2025, 1, 1),
      ));
      await dao.upsertPlaybackState(_makeState(
        episodeId: 2,
        lastUpdatedAt: DateTime(2025, 6, 1),
      ));

      final emitted = <List<PlaybackState>>[];
      final sub = dao.watchAll().listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      // Most recently updated should be first
      expect(emitted.last.first.episodeId, 2);
      expect(emitted.last.last.episodeId, 1);

      await sub.cancel();
    });

    test('emits empty list when no states exist', () async {
      final emitted = <List<PlaybackState>>[];
      final sub = dao.watchAll().listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, isEmpty);

      await sub.cancel();
    });
  });

  group('deleteByEpisodeId', () {
    test('deletes playback state by episode ID', () async {
      await dao.upsertPlaybackState(_makeState(episodeId: 1));
      await dao.upsertPlaybackState(_makeState(episodeId: 2));

      await dao.deleteByEpisodeId(1);

      expect(await dao.getByEpisodeId(1), isNull);
      expect(await dao.getByEpisodeId(2), isNotNull);
    });

    test('does nothing when deleting non-existent episode', () async {
      // Should not throw
      await dao.deleteByEpisodeId(999);
    });
  });

  group('default values', () {
    test('positionSeconds defaults to 0 when absent', () async {
      await dao.upsertPlaybackState(PlaybackStatesCompanion.insert(
        episodeId: const Value(10),
        lastUpdatedAt: DateTime(2025, 1, 1),
      ));

      final state = await dao.getByEpisodeId(10);
      expect(state!.positionSeconds, 0);
    });

    test('playbackRate defaults to 1.0 when absent', () async {
      await dao.upsertPlaybackState(PlaybackStatesCompanion.insert(
        episodeId: const Value(10),
        lastUpdatedAt: DateTime(2025, 1, 1),
      ));

      final state = await dao.getByEpisodeId(10);
      expect(state!.playbackRate, 1.0);
    });

    test('playCount defaults to 0 when absent', () async {
      await dao.upsertPlaybackState(PlaybackStatesCompanion.insert(
        episodeId: const Value(10),
        lastUpdatedAt: DateTime(2025, 1, 1),
      ));

      final state = await dao.getByEpisodeId(10);
      expect(state!.playCount, 0);
    });

    test('isCompleted defaults to false when absent', () async {
      await dao.upsertPlaybackState(PlaybackStatesCompanion.insert(
        episodeId: const Value(10),
        lastUpdatedAt: DateTime(2025, 1, 1),
      ));

      final state = await dao.getByEpisodeId(10);
      expect(state!.isCompleted, isFalse);
    });
  });

  group('playback state lifecycle', () {
    test('full lifecycle: insert, update position, complete, delete', () async {
      // Insert
      await dao.upsertPlaybackState(_makeState(
        episodeId: 42,
        positionSeconds: 0,
        playCount: 0,
        isCompleted: false,
      ));

      var state = await dao.getByEpisodeId(42);
      expect(state!.positionSeconds, 0);
      expect(state.isCompleted, isFalse);

      // Update position
      await dao.updatePosition(42, 300);
      state = await dao.getByEpisodeId(42);
      expect(state!.positionSeconds, 300);

      // Mark completed via upsert
      await dao.upsertPlaybackState(_makeState(
        episodeId: 42,
        positionSeconds: 600,
        isCompleted: true,
        playCount: 1,
      ));
      state = await dao.getByEpisodeId(42);
      expect(state!.isCompleted, isTrue);
      expect(state.playCount, 1);

      // Delete
      await dao.deleteByEpisodeId(42);
      expect(await dao.getByEpisodeId(42), isNull);
    });
  });
}
