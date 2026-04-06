import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_search_model.g.dart';

/// 国家/地区枚举
enum PodcastCountry {
  china('cn', 'podcast_country_china', '🇨🇳', isPopular: true),
  usa('us', 'podcast_country_usa', '🇺🇸', isPopular: true),
  japan('jp', 'podcast_country_japan', '🇯🇵', isPopular: true),
  uk('gb', 'podcast_country_uk', '🇬🇧', isPopular: true),
  germany('de', 'podcast_country_germany', '🇩🇪', isPopular: true),
  france('fr', 'podcast_country_france', '🇫🇷'),
  canada('ca', 'podcast_country_canada', '🇨🇦'),
  australia('au', 'podcast_country_australia', '🇦🇺'),
  korea('kr', 'podcast_country_korea', '🇰🇷'),
  taiwan('tw', 'podcast_country_taiwan', '🇹🇼'),
  hongKong('hk', 'podcast_country_hong_kong', '🇭🇰'),
  india('in', 'podcast_country_india', '🇮🇳'),
  brazil('br', 'podcast_country_brazil', '🇧🇷'),
  mexico('mx', 'podcast_country_mexico', '🇲🇽'),
  spain('es', 'podcast_country_spain', '🇪🇸'),
  italy('it', 'podcast_country_italy', '🇮🇹');

  final String code;
  final String localizationKey;
  final String flag;
  final bool isPopular;

  const PodcastCountry(
    this.code,
    this.localizationKey,
    this.flag, {
    this.isPopular = false,
  });

  /// 获取常用地区列表
  static List<PodcastCountry> get popularRegions =>
      values.where((country) => country.isPopular).toList();
}

/// iTunes 搜索结果模型
@JsonSerializable()
class PodcastSearchResult extends Equatable {

  const PodcastSearchResult({
    this.collectionId,
    this.collectionName,
    this.artistName,
    this.artworkUrl100,
    this.artworkUrl600,
    this.feedUrl,
    this.collectionViewUrl,
    this.primaryGenreName,
    this.trackCount,
    this.releaseDate,
  });

  factory PodcastSearchResult.fromJson(Map<String, dynamic> json) =>
      _$PodcastSearchResultFromJson(json);
  @JsonKey(name: 'collectionId')
  final int? collectionId;
  @JsonKey(name: 'collectionName')
  final String? collectionName;
  @JsonKey(name: 'artistName')
  final String? artistName;
  @JsonKey(name: 'artworkUrl100')
  final String? artworkUrl100;
  @JsonKey(name: 'artworkUrl600')
  final String? artworkUrl600;
  @JsonKey(name: 'feedUrl')
  final String? feedUrl;
  @JsonKey(name: 'collectionViewUrl')
  final String? collectionViewUrl;
  @JsonKey(name: 'primaryGenreName')
  final String? primaryGenreName;
  @JsonKey(name: 'trackCount')
  final int? trackCount;
  @JsonKey(name: 'releaseDate')
  final String? releaseDate;

  Map<String, dynamic> toJson() => _$PodcastSearchResultToJson(this);

  @override
  List<Object?> get props => [
        collectionId,
        collectionName,
        artistName,
        artworkUrl100,
        artworkUrl600,
        feedUrl,
        collectionViewUrl,
        primaryGenreName,
        trackCount,
        releaseDate,
      ];
}

/// iTunes Search API 响应模型
@JsonSerializable()
class ITunesSearchResponse extends Equatable {

  const ITunesSearchResponse({
    required this.resultCount,
    required this.results,
  });

  factory ITunesSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$ITunesSearchResponseFromJson(json);
  final int resultCount;
  final List<PodcastSearchResult> results;

  Map<String, dynamic> toJson() => _$ITunesSearchResponseToJson(this);

  @override
  List<Object?> get props => [resultCount, results];
}
