import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/download_dao.dart';

void main() {
  late AppDatabase db;
  late DownloadDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = DownloadDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  DownloadTasksCompanion _makeTask({
    required int episodeId,
    String audioUrl = 'https://example.com/ep.mp3',
    DownloadStatus status = DownloadStatus.pending,
    double progress = 0,
    int? fileSize,
    String? localPath,
  }) {
    return DownloadTasksCompanion.insert(
      episodeId: episodeId,
      audioUrl: audioUrl,
      status: Value(status),
      progress: Value(progress),
      fileSize: fileSize != null ? Value(fileSize) : const Value.absent(),
      localPath: localPath != null ? Value(localPath) : const Value.absent(),
    );
  }

  group('insertTask & getByEpisodeId', () {
    test('inserts a task and retrieves it by episode ID', () async {
      await dao.insertTask(_makeTask(episodeId: 1));

      final task = await dao.getByEpisodeId(1);

      expect(task, isNotNull);
      expect(task!.episodeId, 1);
      expect(task.audioUrl, 'https://example.com/ep.mp3');
      expect(task.status, DownloadStatus.pending);
      expect(task.progress, 0);
    });

    test('returns null for non-existent episode ID', () async {
      final task = await dao.getByEpisodeId(999);
      expect(task, isNull);
    });

    test('auto-increments id', () async {
      final id1 = await dao.insertTask(_makeTask(episodeId: 10));
      final id2 = await dao.insertTask(_makeTask(episodeId: 20));

      expect(id2, greaterThan(id1));
    });
  });

  group('watchAll', () {
    test('emits tasks ordered by createdAt descending', () async {
      // Use explicit createdAt values to guarantee deterministic ordering,
      // since database-generated defaults can be identical within the same
      // millisecond.
      final older = DateTime.now().subtract(const Duration(seconds: 1));
      final newer = DateTime.now();

      await dao.insertTask(DownloadTasksCompanion.insert(
        episodeId: 1,
        audioUrl: 'https://example.com/ep.mp3',
        createdAt: Value(older),
      ));
      await dao.insertTask(DownloadTasksCompanion.insert(
        episodeId: 2,
        audioUrl: 'https://example.com/ep.mp3',
        createdAt: Value(newer),
      ));

      final emitted = <List<DownloadTask>>[];
      final sub = dao.watchAll().listen(emitted.add);

      // Allow stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      // Latest inserted task should appear first (desc by createdAt)
      expect(emitted.last.first.episodeId, 2);
      expect(emitted.last.last.episodeId, 1);

      await sub.cancel();
    });
  });

  group('watchByEpisodeId', () {
    test('watches a specific episode task', () async {
      await dao.insertTask(_makeTask(episodeId: 5));
      await dao.insertTask(_makeTask(episodeId: 6));

      final emitted = <DownloadTask?>[];
      final sub = dao.watchByEpisodeId(5).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last!.episodeId, 5);

      await sub.cancel();
    });

    test('emits null when episode has no task', () async {
      final emitted = <DownloadTask?>[];
      final sub = dao.watchByEpisodeId(999).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, isNull);

      await sub.cancel();
    });
  });

  group('getAllCompleted', () {
    test('returns only completed tasks', () async {
      await dao.insertTask(_makeTask(
        episodeId: 1,
        status: DownloadStatus.completed,
        localPath: '/path/1.mp3',
      ));
      await dao.insertTask(_makeTask(episodeId: 2, status: DownloadStatus.pending));
      await dao.insertTask(_makeTask(
        episodeId: 3,
        status: DownloadStatus.completed,
        localPath: '/path/3.mp3',
      ));

      final completed = await dao.getAllCompleted();

      expect(completed, hasLength(2));
      expect(completed.every((t) => t.status == DownloadStatus.completed), isTrue);
    });

    test('returns empty list when no tasks are completed', () async {
      await dao.insertTask(_makeTask(episodeId: 1, status: DownloadStatus.downloading));

      final completed = await dao.getAllCompleted();
      expect(completed, isEmpty);
    });
  });

  group('updateProgress', () {
    test('updates progress for a given task id', () async {
      final id = await dao.insertTask(_makeTask(episodeId: 1));

      await dao.updateProgress(id, 0.5);

      final task = await dao.getByEpisodeId(1);
      expect(task!.progress, 0.5);
    });
  });

  group('markCompleted', () {
    test('marks task as completed with local path', () async {
      final id = await dao.insertTask(_makeTask(episodeId: 1));

      await dao.markCompleted(id, '/downloads/ep1.mp3');

      final task = await dao.getByEpisodeId(1);
      expect(task!.status, DownloadStatus.completed);
      expect(task.localPath, '/downloads/ep1.mp3');
      expect(task.progress, 1);
      expect(task.completedAt, isNotNull);
    });
  });

  group('markFailed', () {
    test('marks task as failed', () async {
      final id = await dao.insertTask(_makeTask(episodeId: 1));

      await dao.markFailed(id);

      final task = await dao.getByEpisodeId(1);
      expect(task!.status, DownloadStatus.failed);
    });
  });

  group('markPending', () {
    test('resets task to pending with zero progress', () async {
      final id = await dao.insertTask(_makeTask(
        episodeId: 1,
        status: DownloadStatus.failed,
        progress: 0.7,
      ));

      await dao.markPending(id);

      final task = await dao.getByEpisodeId(1);
      expect(task!.status, DownloadStatus.pending);
      expect(task.progress, 0);
    });
  });

  group('deleteByEpisodeId', () {
    test('deletes task by episode ID', () async {
      await dao.insertTask(_makeTask(episodeId: 1));
      await dao.insertTask(_makeTask(episodeId: 2));

      await dao.deleteByEpisodeId(1);

      expect(await dao.getByEpisodeId(1), isNull);
      expect(await dao.getByEpisodeId(2), isNotNull);
    });
  });

  group('deleteById', () {
    test('deletes task by primary key', () async {
      final id = await dao.insertTask(_makeTask(episodeId: 1));

      await dao.deleteById(id);

      expect(await dao.getByEpisodeId(1), isNull);
    });
  });

  group('getLocalPathByEpisodeId', () {
    test('returns local path when task is completed', () async {
      final id = await dao.insertTask(_makeTask(episodeId: 1));
      await dao.markCompleted(id, '/local/ep1.mp3');

      final path = await dao.getLocalPathByEpisodeId(1);
      expect(path, '/local/ep1.mp3');
    });

    test('returns null when task exists but is not completed', () async {
      await dao.insertTask(_makeTask(episodeId: 1));

      final path = await dao.getLocalPathByEpisodeId(1);
      expect(path, isNull);
    });

    test('returns null when no task exists', () async {
      final path = await dao.getLocalPathByEpisodeId(999);
      expect(path, isNull);
    });
  });

  group('DownloadStatus enum values', () {
    test('pending defaults on insert', () async {
      await dao.insertTask(DownloadTasksCompanion.insert(
        episodeId: 100,
        audioUrl: 'https://example.com/audio.mp3',
      ));

      final task = await dao.getByEpisodeId(100);
      expect(task!.status, DownloadStatus.pending);
    });

    test('all enum statuses round-trip correctly', () async {
      final statuses = DownloadStatus.values;
      for (var i = 0; i < statuses.length; i++) {
        final id = await dao.insertTask(_makeTask(
          episodeId: 100 + i,
          status: statuses[i],
        ));

        final task = await dao.getByEpisodeId(100 + i);
        expect(task!.status, statuses[i]);
      }
    });
  });
}
