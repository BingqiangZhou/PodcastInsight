class AppConstants {
  // Storage keys
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale';
}

// App Update Constants / 应用更新常量
class AppUpdateConstants {
  // GitHub Configuration / GitHub 配置
  static const String githubOwner = 'BingqiangZhou';
  static const String githubRepo = 'Personal-AI-Assistant';
  static const String githubApiBaseUrl = 'https://api.github.com';

  // GitHub API Endpoints / GitHub API 端点
  static String get githubLatestReleaseUrl =>
      '$githubApiBaseUrl/repos/$githubOwner/$githubRepo/releases/latest';

  // Cache Configuration / 缓存配置
  static const Duration updateCheckCacheDuration = Duration(hours: 24);
  static const Duration updateCheckTimeout = Duration(seconds: 10);

  // Storage Keys / 存储键
  static const String lastUpdateCheckKey = 'last_update_check_timestamp';
  static const String cachedReleaseKey = 'cached_github_release';
  static const String skippedVersionKey = 'skipped_update_version';
}
