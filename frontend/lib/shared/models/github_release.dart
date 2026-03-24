import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ai_assistant/core/constants/app_constants.dart';

/// GitHub Release Model / GitHub 发布模型
///
/// Represents a GitHub release with all relevant information
/// for app update notifications.
class GitHubRelease {
  /// Release tag name (e.g., "v1.0.0")
  final String tagName;

  /// Release name
  final String name;

  /// Release version number (extracted from tagName)
  final String version;

  /// Release body/description
  final String body;

  /// Whether this is a pre-release
  final bool prerelease;

  /// Whether this is a draft release
  final bool draft;

  /// Release creation date
  final DateTime createdAt;

  /// Release publication date
  final DateTime publishedAt;

  /// HTML URL for the release page
  final String htmlUrl;

  /// Download assets (installers, etc.)
  final List<GitHubAsset> assets;

  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.version,
    required this.body,
    required this.prerelease,
    required this.draft,
    required this.createdAt,
    required this.publishedAt,
    required this.htmlUrl,
    this.assets = const [],
  });

  /// Create GitHubRelease from JSON
  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    // Extract version from tagName (remove 'v' prefix if present)
    String version = json['tag_name'] as String;
    if (version.startsWith('v')) {
      version = version.substring(1);
    }

    // Parse assets
    final assetsList = <GitHubAsset>[];
    if (json['assets'] != null) {
      for (var asset in json['assets'] as List) {
        assetsList.add(GitHubAsset.fromJson(asset as Map<String, dynamic>));
      }
    }

    return GitHubRelease(
      tagName: json['tag_name'] as String,
      name: json['name'] as String? ?? json['tag_name'] as String,
      version: version,
      body: json['body'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
      draft: json['draft'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: DateTime.parse(json['published_at'] as String),
      htmlUrl: json['html_url'] as String,
      assets: assetsList,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'tag_name': tagName,
      'name': name,
      'version': version,
      'body': body,
      'prerelease': prerelease,
      'draft': draft,
      'created_at': createdAt.toIso8601String(),
      'published_at': publishedAt.toIso8601String(),
      'html_url': htmlUrl,
      'assets': assets.map((a) => a.toJson()).toList(),
    };
  }

  /// Convert to JSON string for storage
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory GitHubRelease.fromJsonString(String jsonString) {
    return GitHubRelease.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Check if this release is newer than the given version
  bool isNewerThan(String currentVersion) {
    try {
      final current = Version.parse(currentVersion);
      final release = Version.parse(version);
      return release > current;
    } catch (e) {
      // If version parsing fails, compare as strings
      return version.compareTo(currentVersion) > 0;
    }
  }

  /// Get the matching asset for a specific platform.
  ///
  /// Uses strict matching rules: the asset file name must contain the platform
  /// keyword AND end with the expected extension for that platform.
  /// Returns `null` if no asset matches — never falls back to an unrelated asset.
  ///
  /// Matching rules:
  /// | Platform  | Keyword    | Extension  |
  /// |-----------|------------|------------|
  /// | android   | android    | .apk       |
  /// | windows   | windows    | .zip       |
  /// | linux     | linux      | .tar.gz    |
  /// | macos     | macos      | .dmg       |
  /// | ios       | ios        | .ipa       |
  GitHubAsset? getAssetForPlatform(String platform) {
    final p = platform.toLowerCase();
    final expectedExtension = switch (p) {
      'android' => '.apk',
      'windows' => '.zip',
      'linux' => '.tar.gz',
      'macos' => '.dmg',
      'ios' => '.ipa',
      _ => null,
    };
    if (expectedExtension == null) return null;

    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (name.contains(p) && name.endsWith(expectedExtension)) {
        return asset;
      }
    }
    return null;
  }

  /// Get the download URL for the current platform.
  ///
  /// Returns `null` if no asset matches the given platform.
  String? getDownloadUrlForPlatform(String platform) {
    return getAssetForPlatform(platform)?.downloadUrl;
  }

  /// Format published date for display
  String get formattedPublishedDate {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${publishedAt.day}/${publishedAt.month}/${publishedAt.year}';
    }
  }

  @override
  String toString() {
    return 'GitHubRelease(tagName: $tagName, version: $version, name: $name)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRelease &&
          runtimeType == other.runtimeType &&
          tagName == other.tagName;

  @override
  int get hashCode => tagName.hashCode;
}

/// GitHub Release Asset Model / GitHub 发布资源模型
class GitHubAsset {
  /// Asset name (e.g., "app-windows-x64.exe")
  final String name;

  /// Download URL
  final String downloadUrl;

  /// File size in bytes
  final int size;

  /// Download count
  final int downloadCount;

  /// Content type
  final String contentType;

  const GitHubAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.downloadCount,
    required this.contentType,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] as String,
      downloadUrl: json['browser_download_url'] as String,
      size: json['size'] as int,
      downloadCount: json['download_count'] as int,
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'browser_download_url': downloadUrl,
      'size': size,
      'download_count': downloadCount,
      'content_type': contentType,
    };
  }

  /// Format file size for display
  String get formattedSize {
    if (size < 1024) {
      return '${size}B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)}KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }

  @override
  String toString() {
    return 'GitHubAsset(name: $name, size: $formattedSize)';
  }
}

/// Simple version comparison utility / 简单版本比较工具
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  const Version({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
  });

  factory Version.parse(String versionString) {
    final parts = versionString.split('-');
    final versionPart = parts[0];
    final preReleaseValue = parts.length > 1 ? parts.sublist(1).join('-') : null;

    final numbers = versionPart.split('.');
    return Version(
      major: numbers.isNotEmpty ? int.parse(numbers[0]) : 0,
      minor: numbers.length > 1 ? int.parse(numbers[1]) : 0,
      patch: numbers.length > 2 ? int.parse(numbers[2]) : 0,
      preRelease: preReleaseValue,
    );
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Handle pre-release comparison
    // null (stable release) > pre-release
    final thisPre = preRelease;
    final otherPre = other.preRelease;

    if (thisPre == null && otherPre == null) return 0;
    if (thisPre == null) return 1; // stable > pre-release
    if (otherPre == null) return -1; // pre-release < stable
    return thisPre.compareTo(otherPre);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Version &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          preRelease == other.preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return preRelease != null ? '$base-$preRelease' : base;
  }

  bool operator >(Version other) => compareTo(other) > 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator <(Version other) => compareTo(other) < 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
}

/// Repository for caching GitHub releases / GitHub 发布缓存仓库
class GitHubReleaseCache {
  /// Save release to cache
  static Future<void> save(GitHubRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppUpdateConstants.cachedReleaseKey,
      release.toJsonString(),
    );
    await prefs.setInt(
      AppUpdateConstants.lastUpdateCheckKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get cached release
  static Future<GitHubRelease?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(AppUpdateConstants.cachedReleaseKey);
    if (jsonString == null) return null;
    return GitHubRelease.fromJsonString(jsonString);
  }

  /// Get last update check timestamp
  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(AppUpdateConstants.lastUpdateCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Check if cache is still valid
  static Future<bool> isCacheValid() async {
    final lastCheck = await getLastCheckTime();
    if (lastCheck == null) return false;

    final now = DateTime.now();
    final difference = now.difference(lastCheck);
    return difference < AppUpdateConstants.updateCheckCacheDuration;
  }

  /// Clear cache
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppUpdateConstants.cachedReleaseKey);
    await prefs.remove(AppUpdateConstants.lastUpdateCheckKey);
  }

  /// Save skipped version
  static Future<void> saveSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppUpdateConstants.skippedVersionKey, version);
  }

  /// Get skipped version
  static Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppUpdateConstants.skippedVersionKey);
  }

  /// Clear skipped version
  static Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppUpdateConstants.skippedVersionKey);
  }
}
