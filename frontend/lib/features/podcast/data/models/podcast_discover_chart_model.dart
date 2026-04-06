import 'package:equatable/equatable.dart';

enum ApplePodcastRssFormat {
  json('json'),
  rss('rss'),
  atom('atom');

  const ApplePodcastRssFormat(this.value);
  final String value;
}

enum PodcastDiscoverKind {
  podcasts('podcasts'),
  podcastEpisodes('podcast-episodes');

  const PodcastDiscoverKind(this.value);
  final String value;
}

class ApplePodcastGenre {

  const ApplePodcastGenre({required this.name, this.genreId, this.url});

  factory ApplePodcastGenre.fromJson(Map<String, dynamic> json) {
    return ApplePodcastGenre(
      genreId: json['genreId']?.toString(),
      name: (json['name'] as String?)?.trim() ?? 'Unknown',
      url: json['url'] as String?,
    );
  }
  final String? genreId;
  final String name;
  final String? url;
}

class ApplePodcastChartEntry {

  const ApplePodcastChartEntry({
    required this.id,
    required this.name,
    required this.artistName,
    required this.kind,
    required this.url, required this.genres, this.contentAdvisoryRating,
    this.artworkUrl100,
  });

  factory ApplePodcastChartEntry.fromJson(Map<String, dynamic> json) {
    final genresJson = json['genres'] as List<dynamic>? ?? const [];
    return ApplePodcastChartEntry(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim() ?? 'Unknown',
      artistName: (json['artistName'] as String?)?.trim() ?? 'Unknown',
      kind: (json['kind'] as String?)?.trim() ?? '',
      contentAdvisoryRating: json['contentAdvisoryRating'] as String?,
      artworkUrl100: json['artworkUrl100'] as String?,
      url: (json['url'] as String?)?.trim() ?? '',
      genres: genresJson
          .whereType<Map<String, dynamic>>()
          .map(ApplePodcastGenre.fromJson)
          .toList(),
    );
  }
  final String id;
  final String name;
  final String artistName;
  final String kind;
  final String? contentAdvisoryRating;
  final String? artworkUrl100;
  final String url;
  final List<ApplePodcastGenre> genres;
}

class ApplePodcastChartFeed {

  const ApplePodcastChartFeed({
    required this.title,
    required this.country,
    required this.results, this.updated,
  });

  factory ApplePodcastChartFeed.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>? ?? const [];
    return ApplePodcastChartFeed(
      title: (json['title'] as String?)?.trim() ?? '',
      country: (json['country'] as String?)?.trim() ?? '',
      updated: json['updated'] as String?,
      results: resultsJson
          .whereType<Map<String, dynamic>>()
          .map(ApplePodcastChartEntry.fromJson)
          .toList(),
    );
  }
  final String title;
  final String country;
  final String? updated;
  final List<ApplePodcastChartEntry> results;
}

class ApplePodcastChartResponse {

  const ApplePodcastChartResponse({required this.feed});

  factory ApplePodcastChartResponse.fromJson(Map<String, dynamic> json) {
    final feedJson = json['feed'] as Map<String, dynamic>? ?? const {};
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed.fromJson(feedJson),
    );
  }
  final ApplePodcastChartFeed feed;
}

class PodcastDiscoverItem extends Equatable {

  const PodcastDiscoverItem({
    required this.itemId,
    required this.itunesId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.url,
    required this.genres,
    required this.kind,
  });

  factory PodcastDiscoverItem.fromChartEntry(
    ApplePodcastChartEntry entry, {
    required PodcastDiscoverKind defaultKind,
  }) {
    final parsedId = int.tryParse(entry.id);
    final resolvedKind = entry.kind == PodcastDiscoverKind.podcastEpisodes.value
        ? PodcastDiscoverKind.podcastEpisodes
        : PodcastDiscoverKind.podcasts;

    return PodcastDiscoverItem(
      itemId: entry.id,
      itunesId: parsedId,
      title: entry.name,
      artist: entry.artistName,
      artworkUrl: entry.artworkUrl100,
      url: entry.url,
      genres: entry.genres
          .map((item) => item.name)
          .where((name) => name.isNotEmpty)
          .toList(),
      kind: entry.kind.isNotEmpty ? resolvedKind : defaultKind,
    );
  }
  final String itemId;
  final int? itunesId;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String url;
  final List<String> genres;
  final PodcastDiscoverKind kind;

  bool get isPodcastShow => kind == PodcastDiscoverKind.podcasts;

  bool hasGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return genres.any((item) => item.toLowerCase() == normalized);
  }

  @override
  List<Object?> get props => [
    itemId,
    itunesId,
    title,
    artist,
    artworkUrl,
    url,
    genres,
    kind,
  ];
}
