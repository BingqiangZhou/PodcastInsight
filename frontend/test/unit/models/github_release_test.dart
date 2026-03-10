import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/shared/models/github_release.dart';

void main() {
  GitHubRelease buildReleaseWithAssets(List<GitHubAsset> assets) {
    return GitHubRelease(
      tagName: 'v1.0.0',
      name: 'Release v1.0.0',
      version: '1.0.0',
      body: '',
      prerelease: false,
      draft: false,
      createdAt: DateTime(2026, 1, 1),
      publishedAt: DateTime(2026, 1, 1),
      htmlUrl: 'https://github.com/example/repo/releases/tag/v1.0.0',
      assets: assets,
    );
  }

  GitHubAsset buildAsset(String name) {
    return GitHubAsset(
      name: name,
      downloadUrl: 'https://github.com/example/repo/releases/download/v1.0.0/$name',
      size: 10 * 1024 * 1024,
      downloadCount: 100,
      contentType: 'application/octet-stream',
    );
  }

  group('GitHubRelease.getAssetForPlatform', () {
    test('Windows release with both Windows ZIP and Android APK returns only ZIP for windows', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-arm64-1.0.0.apk'),
        buildAsset('personal-ai-assistant-windows-1.0.0.zip'),
      ]);

      final asset = release.getAssetForPlatform('windows');
      expect(asset, isNotNull);
      expect(asset!.name, contains('windows'));
      expect(asset.name, endsWith('.zip'));
    });

    test('Android returns only APK', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-arm64-1.0.0.apk'),
        buildAsset('personal-ai-assistant-windows-1.0.0.zip'),
      ]);

      final asset = release.getAssetForPlatform('android');
      expect(asset, isNotNull);
      expect(asset!.name, contains('android'));
      expect(asset.name, endsWith('.apk'));
    });

    test('returns null when no asset matches the platform', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-arm64-1.0.0.apk'),
      ]);

      final asset = release.getAssetForPlatform('windows');
      expect(asset, isNull);
    });

    test('never falls back to first asset on mismatch', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-arm64-1.0.0.apk'),
        buildAsset('personal-ai-assistant-linux-1.0.0.tar.gz'),
      ]);

      final asset = release.getAssetForPlatform('windows');
      expect(asset, isNull);
    });

    test('matches Linux .tar.gz correctly', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-linux-1.0.0.tar.gz'),
      ]);

      final asset = release.getAssetForPlatform('linux');
      expect(asset, isNotNull);
      expect(asset!.name, contains('linux'));
      expect(asset.name, endsWith('.tar.gz'));
    });

    test('matches macOS .dmg correctly', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-macos-1.0.0.dmg'),
      ]);

      final asset = release.getAssetForPlatform('macos');
      expect(asset, isNotNull);
      expect(asset!.name, contains('macos'));
      expect(asset.name, endsWith('.dmg'));
    });

    test('matches iOS .ipa correctly', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-ios-1.0.0.ipa'),
      ]);

      final asset = release.getAssetForPlatform('ios');
      expect(asset, isNotNull);
      expect(asset!.name, contains('ios'));
      expect(asset.name, endsWith('.ipa'));
    });

    test('returns null for unknown platform', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-windows-1.0.0.zip'),
      ]);

      final asset = release.getAssetForPlatform('web');
      expect(asset, isNull);
    });

    test('returns null when assets list is empty', () {
      final release = buildReleaseWithAssets([]);

      final asset = release.getAssetForPlatform('windows');
      expect(asset, isNull);
    });

    test('requires BOTH platform keyword AND correct extension', () {
      // A .zip file that contains "android" in its name should NOT match android
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-debug.zip'),
      ]);

      final asset = release.getAssetForPlatform('android');
      expect(asset, isNull, reason: 'android requires .apk extension, not .zip');
    });
  });

  group('GitHubRelease.getDownloadUrlForPlatform', () {
    test('returns URL when platform matches', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-windows-1.0.0.zip'),
      ]);

      final url = release.getDownloadUrlForPlatform('windows');
      expect(url, isNotNull);
      expect(url, contains('windows'));
    });

    test('returns null when no match (no fallback)', () {
      final release = buildReleaseWithAssets([
        buildAsset('personal-ai-assistant-android-arm64-1.0.0.apk'),
      ]);

      final url = release.getDownloadUrlForPlatform('windows');
      expect(url, isNull);
    });
  });
}
