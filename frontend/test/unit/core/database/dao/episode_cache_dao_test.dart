import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/episode_cache_dao.dart';

void main() {
  late AppDatabase db;
  late EpisodeCacheDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = EpisodeCacheDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  EpisodesCacheCompanion _makeEpisode({
    required int id,
    required int subscriptionId,
    String title = 'Test Episode',
    String audioUrl = 'https://example.com/ep.mp3',
    String? imageUrl,
    int? audioDuration,
    String? subscriptionTitle,
    String? subscriptionImageUrl,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return EpisodesCacheCompanion.insert(
      id: Value(id),
      subscriptionId: subscriptionId,
      title: title,
      audioUrl: audioUrl,
      imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
      audioDuration: audioDuration != null ? Value(audioDuration) : const Value.absent(),
      subscriptionTitle: subscriptionTitle != null ? Value(subscriptionTitle) : const Value.absent(),
      subscriptionImageUrl: subscriptionImageUrl != null ? Value(subscriptionImageUrl) : const Value.absent(),
      publishedAt: publishedAt ?? DateTime(2025, 1, 1),
      updatedAt: updatedAt ?? DateTime(2025, 1, 1),
    );
  }

  group('upsertEpisode & getById', () {
    test('inserts and retrieves an episode', () async {
      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10));

      final ep = await dao.getById(1);

      expect(ep, isNotNull);
      expect(ep!.id, 1);
      expect(ep.subscriptionId, 10);
      expect(ep.title, 'Test Episode');
      expect(ep.audioUrl, 'https://example.com/ep.mp3');
    });

    test('returns null for non-existent id', () async {
      final ep = await dao.getById(999);
      expect(ep, isNull);
    });

    test('upserts (replaces) existing episode on conflict', () async {
      await dao.upsertEpisode(_makeEpisode(
        id: 1,
        subscriptionId: 10,
        title: 'Original Title',
      ));

      await dao.upsertEpisode(_makeEpisode(
        id: 1,
        subscriptionId: 10,
        title: 'Updated Title',
      ));

      final ep = await dao.getById(1);
      expect(ep!.title, 'Updated Title');
    });
  });

  group('upsertAll', () {
    test('bulk inserts multiple episodes', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10),
        _makeEpisode(id: 2, subscriptionId: 10),
        _makeEpisode(id: 3, subscriptionId: 20),
      ]);

      expect(await dao.getById(1), isNotNull);
      expect(await dao.getById(2), isNotNull);
      expect(await dao.getById(3), isNotNull);
    });

    test('bulk upserts update existing entries', () async {
      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10, title: 'Old'));

      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, title: 'New'),
      ]);

      final ep = await dao.getById(1);
      expect(ep!.title, 'New');
    });
  });

  group('getBySubscriptionId', () {
    test('returns episodes for a specific subscription', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10),
        _makeEpisode(id: 2, subscriptionId: 10),
        _makeEpisode(id: 3, subscriptionId: 20),
      ]);

      final eps = await dao.getBySubscriptionId(10);

      expect(eps, hasLength(2));
      expect(eps.every((e) => e.subscriptionId == 10), isTrue);
    });

    test('orders by publishedAt descending', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, publishedAt: DateTime(2025, 1, 1)),
        _makeEpisode(id: 2, subscriptionId: 10, publishedAt: DateTime(2025, 3, 1)),
        _makeEpisode(id: 3, subscriptionId: 10, publishedAt: DateTime(2025, 2, 1)),
      ]);

      final eps = await dao.getBySubscriptionId(10);

      expect(eps[0].id, 2); // March
      expect(eps[1].id, 3); // February
      expect(eps[2].id, 1); // January
    });

    test('returns empty list for subscription with no episodes', () async {
      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10));

      final eps = await dao.getBySubscriptionId(999);
      expect(eps, isEmpty);
    });
  });

  group('watchAll', () {
    test('emits all episodes ordered by publishedAt descending', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, publishedAt: DateTime(2025, 1, 1)),
        _makeEpisode(id: 2, subscriptionId: 10, publishedAt: DateTime(2025, 3, 1)),
      ]);

      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchAll().listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last.first.id, 2);
      expect(emitted.last.last.id, 1);

      await sub.cancel();
    });

    test('emits empty list when no episodes cached', () async {
      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchAll().listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, isEmpty);

      await sub.cancel();
    });
  });

  group('deleteById', () {
    test('deletes a cached episode by id', () async {
      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10));
      await dao.upsertEpisode(_makeEpisode(id: 2, subscriptionId: 10));

      await dao.deleteById(1);

      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('does nothing for non-existent id', () async {
      await dao.deleteById(999); // should not throw
    });
  });

  group('deleteBySubscriptionId', () {
    test('deletes all episodes for a subscription', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10),
        _makeEpisode(id: 2, subscriptionId: 10),
        _makeEpisode(id: 3, subscriptionId: 20),
      ]);

      await dao.deleteBySubscriptionId(10);

      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNull);
      expect(await dao.getById(3), isNotNull);
    });

    test('does nothing for non-existent subscription', () async {
      await dao.deleteBySubscriptionId(999); // should not throw
    });
  });

  group('evictStaleEntries', () {
    test('evicts entries older than maxAge', () async {
      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 10));
      final recentDate = now.subtract(const Duration(days: 1));

      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, updatedAt: oldDate),
        _makeEpisode(id: 2, subscriptionId: 10, updatedAt: oldDate),
        _makeEpisode(id: 3, subscriptionId: 10, updatedAt: recentDate),
      ]);

      final deleted = await dao.evictStaleEntries(maxAge: const Duration(days: 7));

      expect(deleted, 2);
      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNull);
      expect(await dao.getById(3), isNotNull);
    });

    test('does not evict entries exactly at the boundary', () async {
      final now = DateTime.now();
      // Entry updated exactly 7 days ago -- isSmallerThanValue uses strict <
      final boundaryDate = now.subtract(const Duration(days: 7));

      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10, updatedAt: boundaryDate));

      final deleted = await dao.evictStaleEntries(maxAge: const Duration(days: 7));

      expect(deleted, 0);
      expect(await dao.getById(1), isNotNull);
    });

    test('evicts nothing when all entries are fresh', () async {
      final now = DateTime.now();

      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, updatedAt: now),
        _makeEpisode(id: 2, subscriptionId: 10, updatedAt: now.subtract(const Duration(hours: 1))),
      ]);

      final deleted = await dao.evictStaleEntries();

      expect(deleted, 0);
      expect(await dao.getById(1), isNotNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('custom maxAge works correctly', () async {
      final now = DateTime.now();

      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, updatedAt: now.subtract(const Duration(days: 2))),
        _makeEpisode(id: 2, subscriptionId: 10, updatedAt: now.subtract(const Duration(hours: 12))),
      ]);

      final deleted = await dao.evictStaleEntries(maxAge: const Duration(days: 1));

      expect(deleted, 1);
      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('returns 0 when table is empty', () async {
      final deleted = await dao.evictStaleEntries();
      expect(deleted, 0);
    });
  });

  group('watchFiltered', () {
    test('watches all episodes when no filters applied', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10),
        _makeEpisode(id: 2, subscriptionId: 20),
      ]);

      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchFiltered().listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(2));

      await sub.cancel();
    });

    test('filters by subscriptionId', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10),
        _makeEpisode(id: 2, subscriptionId: 10),
        _makeEpisode(id: 3, subscriptionId: 20),
      ]);

      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchFiltered(subscriptionId: 10).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(2));
      expect(emitted.last.every((e) => e.subscriptionId == 10), isTrue);

      await sub.cancel();
    });

    test('limits results', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, publishedAt: DateTime(2025, 1, 1)),
        _makeEpisode(id: 2, subscriptionId: 10, publishedAt: DateTime(2025, 2, 1)),
        _makeEpisode(id: 3, subscriptionId: 10, publishedAt: DateTime(2025, 3, 1)),
      ]);

      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchFiltered(limit: 2).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(2));
      // Most recent first
      expect(emitted.last.first.id, 3);

      await sub.cancel();
    });

    test('combines subscriptionId and limit filters', () async {
      await dao.upsertAll([
        _makeEpisode(id: 1, subscriptionId: 10, publishedAt: DateTime(2025, 1, 1)),
        _makeEpisode(id: 2, subscriptionId: 10, publishedAt: DateTime(2025, 2, 1)),
        _makeEpisode(id: 3, subscriptionId: 10, publishedAt: DateTime(2025, 3, 1)),
        _makeEpisode(id: 4, subscriptionId: 20, publishedAt: DateTime(2025, 4, 1)),
      ]);

      final emitted = <List<EpisodesCacheData>>[];
      final sub = dao.watchFiltered(subscriptionId: 10, limit: 2).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(2));
      expect(emitted.last.every((e) => e.subscriptionId == 10), isTrue);
      // Most recent subscription 10 episodes first
      expect(emitted.last.first.id, 3);

      await sub.cancel();
    });
  });

  group('nullable fields', () {
    test('stores and retrieves nullable fields correctly', () async {
      await dao.upsertEpisode(EpisodesCacheCompanion.insert(
        id: const Value(1),
        subscriptionId: 10,
        title: 'Episode with optionals',
        audioUrl: 'https://example.com/ep.mp3',
        imageUrl: const Value('https://img.example.com/cover.jpg'),
        audioDuration: const Value(3600),
        subscriptionTitle: const Value('My Podcast'),
        subscriptionImageUrl: const Value('https://img.example.com/pod.jpg'),
        publishedAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ));

      final ep = await dao.getById(1);
      expect(ep!.imageUrl, 'https://img.example.com/cover.jpg');
      expect(ep.audioDuration, 3600);
      expect(ep.subscriptionTitle, 'My Podcast');
      expect(ep.subscriptionImageUrl, 'https://img.example.com/pod.jpg');
    });

    test('nullable fields default to null when absent', () async {
      await dao.upsertEpisode(_makeEpisode(id: 1, subscriptionId: 10));

      final ep = await dao.getById(1);
      expect(ep!.imageUrl, isNull);
      expect(ep.audioDuration, isNull);
      expect(ep.subscriptionTitle, isNull);
      expect(ep.subscriptionImageUrl, isNull);
    });
  });
}
