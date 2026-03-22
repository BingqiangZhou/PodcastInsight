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
  final String? genreId;
  final String name;
  final String? url;

  const ApplePodcastGenre({this.genreId, required this.name, this.url});

  factory ApplePodcastGenre.fromJson(Map<String, dynamic> json) {
    return ApplePodcastGenre(
      genreId: json['genreId']?.toString(),
      name: (json['name'] as String?)?.trim() ?? 'Unknown',
      url: json['url'] as String?,
    );
  }
}

class ApplePodcastChartEntry {
  final String id;
  final String name;
  final String artistName;
  final String kind;
  final String? contentAdvisoryRating;
  final String? artworkUrl100;
  final String url;
  final List<ApplePodcastGenre> genres;

  const ApplePodcastChartEntry({
    required this.id,
    required this.name,
    required this.artistName,
    required this.kind,
    this.contentAdvisoryRating,
    this.artworkUrl100,
    required this.url,
    required this.genres,
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
}

class ApplePodcastChartFeed {
  final String title;
  final String country;
  final String? updated;
  final List<ApplePodcastChartEntry> results;

  const ApplePodcastChartFeed({
    required this.title,
    required this.country,
    this.updated,
    required this.results,
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
}

class ApplePodcastChartResponse {
  final ApplePodcastChartFeed feed;

  const ApplePodcastChartResponse({required this.feed});

  factory ApplePodcastChartResponse.fromJson(Map<String, dynamic> json) {
    final feedJson = json['feed'] as Map<String, dynamic>? ?? const {};
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed.fromJson(feedJson),
    );
  }
}

class PodcastDiscoverItem extends Equatable {
  final String itemId;
  final int? itunesId;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String url;
  final List<String> genres;
  final PodcastDiscoverKind kind;

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

  bool get isPodcastShow => kind == PodcastDiscoverKind.podcasts;

  bool hasGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return genres.any((item) => item.toLowerCase() == normalized);
  }

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
