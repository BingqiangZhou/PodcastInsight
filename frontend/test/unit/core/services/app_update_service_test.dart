import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/services/app_update_service.dart';
import 'package:personal_ai_assistant/shared/models/github_release.dart';

GitHubRelease _makeRelease({
  String tagName = 'v1.0.0',
  String name = 'Release',
  List<GitHubAsset> assets = const [],
}) {
  return GitHubRelease(
    tagName: tagName,
    name: name,
    version: tagName.replaceFirst('v', ''),
    body: '',
    prerelease: false,
    draft: false,
    createdAt: DateTime(2025),
    publishedAt: DateTime(2025),
    htmlUrl: '',
    assets: assets,
  );
}

GitHubAsset _makeAsset(String assetName, {String? url}) {
  return GitHubAsset(
    name: assetName,
    downloadUrl: url ?? 'https://example.com/$assetName',
    size: 1024,
    downloadCount: 0,
    contentType: 'application/octet-stream',
  );
}

void main() {
  group('getAvailablePlatforms', () {
    late AppUpdateService service;

    setUp(() {
      service = AppUpdateService();
    });

    test('identifies windows platform from exe asset', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-windows.exe'),
      ]);
      expect(service.getAvailablePlatforms(release), contains('windows'));
    });

    test('identifies macos platform from dmg asset', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-macos.dmg'),
      ]);
      expect(service.getAvailablePlatforms(release), contains('macos'));
    });

    test('identifies linux platform from appimage asset', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-linux.AppImage'),
      ]);
      expect(service.getAvailablePlatforms(release), contains('linux'));
    });

    test('identifies android platform from apk asset', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-android.apk'),
      ]);
      expect(service.getAvailablePlatforms(release), contains('android'));
    });

    test('identifies multiple platforms', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-windows.exe'),
        _makeAsset('app-macos.dmg'),
        _makeAsset('app-android.apk'),
      ]);
      final platforms = service.getAvailablePlatforms(release);
      expect(platforms, containsAll(['android', 'macos', 'windows']));
    });

    test('returns empty list for no matching assets', () {
      final release = _makeRelease(assets: [
        _makeAsset('checksums.txt'),
        _makeAsset('SHA256SUMS'),
      ]);
      expect(service.getAvailablePlatforms(release), isEmpty);
    });

    test('deduplicates platforms', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-windows.exe'),
        _makeAsset('app-windows-portable.exe'),
      ]);
      final platforms = service.getAvailablePlatforms(release);
      expect(platforms.where((p) => p == 'windows').length, 1);
    });
  });

  group('getDownloadUrl', () {
    late AppUpdateService service;

    setUp(() {
      service = AppUpdateService();
    });

    test('returns null for release with no assets', () {
      final release = _makeRelease();
      expect(service.getDownloadUrl(release), isNull);
    });
  });

  group('GitHubRelease', () {
    test('isNewerThan compares versions correctly', () {
      final release = _makeRelease(tagName: 'v2.0.0');
      expect(release.isNewerThan('1.0.0'), isTrue);
      expect(release.isNewerThan('2.0.0'), isFalse);
      expect(release.isNewerThan('3.0.0'), isFalse);
    });

    test('isNewerThan handles patch versions', () {
      final release = _makeRelease(tagName: 'v1.2.3');
      expect(release.isNewerThan('1.2.2'), isTrue);
      expect(release.isNewerThan('1.2.3'), isFalse);
      expect(release.isNewerThan('1.2.4'), isFalse);
    });

    test('isNewerThan handles minor versions', () {
      final release = _makeRelease(tagName: 'v1.3.0');
      expect(release.isNewerThan('1.2.9'), isTrue);
      expect(release.isNewerThan('1.3.0'), isFalse);
    });

    test('getAssetForPlatform matches correctly', () {
      final release = _makeRelease(assets: [
        _makeAsset('app-windows.zip'),
        _makeAsset('app-macos.dmg'),
        _makeAsset('app-android.apk'),
      ]);

      final asset = release.getAssetForPlatform('windows');
      expect(asset, isNotNull);
      expect(asset!.name, 'app-windows.zip');

      final macAsset = release.getAssetForPlatform('macos');
      expect(macAsset, isNotNull);
      expect(macAsset!.name, 'app-macos.dmg');

      final noAsset = release.getAssetForPlatform('ios');
      expect(noAsset, isNull);
    });

    test('fromJson parses a valid release', () {
      final json = {
        'tag_name': 'v1.5.0',
        'name': 'Release 1.5.0',
        'body': 'Release notes',
        'prerelease': false,
        'draft': false,
        'created_at': '2025-01-01T00:00:00Z',
        'published_at': '2025-01-01T00:00:00Z',
        'html_url': 'https://github.com/example/release',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'https://example.com/app.apk',
            'size': 2048,
            'download_count': 100,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      };

      final release = GitHubRelease.fromJson(json);
      expect(release.tagName, 'v1.5.0');
      expect(release.version, '1.5.0');
      expect(release.name, 'Release 1.5.0');
      expect(release.assets.length, 1);
      expect(release.assets.first.name, 'app.apk');
    });
  });

  group('getCurrentVersionSync', () {
    test('returns a version string', () {
      final version = AppUpdateService.getCurrentVersionSync();
      expect(version, isNotEmpty);
      // Should match semver pattern
      expect(RegExp(r'^\d+\.\d+\.\d+').hasMatch(version), isTrue);
    });
  });
}
