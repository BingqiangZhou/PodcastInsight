// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$EpisodeCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $EpisodesCacheTable get episodesCache => attachedDatabase.episodesCache;
  EpisodeCacheDaoManager get managers => EpisodeCacheDaoManager(this);
}

class EpisodeCacheDaoManager {
  final _$EpisodeCacheDaoMixin _db;
  EpisodeCacheDaoManager(this._db);
  $$EpisodesCacheTableTableManager get episodesCache =>
      $$EpisodesCacheTableTableManager(_db.attachedDatabase, _db.episodesCache);
}
