class ITunesPodcastEpisodeResult {
  const ITunesPodcastEpisodeResult({
    required this.trackId,
    required this.collectionId,
    required this.trackName,
    required this.collectionName,
    required this.feedUrl,
    this.description,
    this.shortDescription,
    this.releaseDate,
    this.episodeUrl,
    this.previewUrl,
    this.trackTimeMillis,
    this.trackViewUrl,
    this.artworkUrl60,
    this.artworkUrl100,
    this.artworkUrl160,
    this.artworkUrl600,
  });

  factory ITunesPodcastEpisodeResult.fromJson(Map<String, dynamic> json) {
    return ITunesPodcastEpisodeResult(
      trackId: (json['trackId'] as num?)?.toInt() ?? 0,
      collectionId: (json['collectionId'] as num?)?.toInt() ?? 0,
      trackName: (json['trackName'] as String?)?.trim() ?? '',
      collectionName: (json['collectionName'] as String?)?.trim() ?? '',
      feedUrl: (json['feedUrl'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      shortDescription: (json['shortDescription'] as String?)?.trim(),
      releaseDate: DateTime.tryParse((json['releaseDate'] as String?) ?? ''),
      episodeUrl: (json['episodeUrl'] as String?)?.trim(),
      previewUrl: (json['previewUrl'] as String?)?.trim(),
      trackTimeMillis: (json['trackTimeMillis'] as num?)?.toInt(),
      trackViewUrl: (json['trackViewUrl'] as String?)?.trim(),
      artworkUrl60: (json['artworkUrl60'] as String?)?.trim(),
      artworkUrl100: (json['artworkUrl100'] as String?)?.trim(),
      artworkUrl160: (json['artworkUrl160'] as String?)?.trim(),
      artworkUrl600: (json['artworkUrl600'] as String?)?.trim(),
    );
  }

  final int trackId;
  final int collectionId;
  final String trackName;
  final String collectionName;
  final String? feedUrl;
  final String? description;
  final String? shortDescription;
  final DateTime? releaseDate;
  final String? episodeUrl;
  final String? previewUrl;
  final int? trackTimeMillis;
  final String? trackViewUrl;
  final String? artworkUrl60;
  final String? artworkUrl100;
  final String? artworkUrl160;
  final String? artworkUrl600;

  String? get resolvedAudioUrl {
    final direct = episodeUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final preview = previewUrl?.trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }
    return null;
  }
}

class ITunesPodcastLookupResult {
  const ITunesPodcastLookupResult({
    required this.showId,
    required this.collectionName,
    required this.artistName,
    required this.feedUrl,
    required this.collectionViewUrl,
    required this.episodes,
  });

  factory ITunesPodcastLookupResult.fromLookupJson(
    Map<String, dynamic> json, {
    required int showId,
  }) {
    final rawResults = (json['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final showEntry = rawResults.firstWhere(
      (item) =>
          (item['kind'] as String?) == 'podcast' ||
          (item['trackId'] as num?)?.toInt() == showId,
      orElse: () => <String, dynamic>{},
    );

    final episodes = rawResults
        .where(
          (item) =>
              (item['wrapperType'] as String?) == 'podcastEpisode' ||
              (item['kind'] as String?) == 'podcast-episode',
        )
        .map(ITunesPodcastEpisodeResult.fromJson)
        .where((episode) => episode.trackId > 0)
        .toList();

    return ITunesPodcastLookupResult(
      showId: showId,
      collectionName: (showEntry['collectionName'] as String?)?.trim(),
      artistName: (showEntry['artistName'] as String?)?.trim(),
      feedUrl: (showEntry['feedUrl'] as String?)?.trim(),
      collectionViewUrl: (showEntry['collectionViewUrl'] as String?)?.trim(),
      episodes: episodes,
    );
  }

  final int showId;
  final String? collectionName;
  final String? artistName;
  final String? feedUrl;
  final String? collectionViewUrl;
  final List<ITunesPodcastEpisodeResult> episodes;

  ITunesPodcastEpisodeResult? findEpisodeByTrackId(int trackId) {
    for (final episode in episodes) {
      if (episode.trackId == trackId) {
        return episode;
      }
    }
    return null;
  }
}
