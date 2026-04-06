import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorageService {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);

  Future<void> saveBool(String key, bool value);
  Future<bool?> getBool(String key);

  Future<void> saveInt(String key, int value);
  Future<int?> getInt(String key);

  Future<void> saveDouble(String key, double value);
  Future<double?> getDouble(String key);

  Future<void> saveStringList(String key, List<String> value);
  Future<List<String>?> getStringList(String key);

  Future<void> save<T>(String key, T value);
  Future<T?> get<T>(String key);

  Future<void> remove(String key);
  Future<void> clear();
  Future<bool> containsKey(String key);

  // Cache methods
  Future<void> cacheData(String key, dynamic data, {Duration? expiration});
  Future<T?> getCachedData<T>(String key);
  Future<void> clearExpiredCache();

  // App Config
  Future<void> saveApiBaseUrl(String url);
  Future<String?> getApiBaseUrl();

  // Server Config (backend server address)
  Future<void> saveServerBaseUrl(String url);
  Future<String?> getServerBaseUrl();
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden');
});

class LocalStorageServiceImpl implements LocalStorageService { // 24 hours in ms

  LocalStorageServiceImpl(this._prefs);
  final SharedPreferences _prefs;
  static const String _cachePrefix = 'cache_';
  static const String _timestampPrefix = 'ts_';
  static const String _expirationSuffix = '_exp';
  static const int _defaultCacheDuration =
      24 * 60 * 60 * 1000;

  String _cacheKey(String key) => '$_cachePrefix$key';
  String _timestampKey(String key) => '$_timestampPrefix$key';
  String _expirationKey(String key) => '$_cachePrefix$key$_expirationSuffix';

  @override
  Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  @override
  Future<void> saveInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    return _prefs.getInt(key);
  }

  @override
  Future<void> saveDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  @override
  Future<double?> getDouble(String key) async {
    return _prefs.getDouble(key);
  }

  @override
  Future<void> saveStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    return _prefs.getStringList(key);
  }

  @override
  Future<void> save<T>(String key, T value) async {
    final jsonString = jsonEncode(value);
    await _prefs.setString(key, jsonString);
  }

  @override
  Future<T?> get<T>(String key) async {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as T;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
    await _prefs.remove(_cacheKey(key));
    await _prefs.remove(_timestampKey(key));
    await _prefs.remove(_expirationKey(key));
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _prefs.containsKey(key);
  }

  @override
  Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? expiration,
  }) async {
    final expirationTime = expiration?.inMilliseconds ?? _defaultCacheDuration;

    await _prefs.setString(_cacheKey(key), jsonEncode(data));
    await _prefs.setInt(
      _timestampKey(key),
      DateTime.now().millisecondsSinceEpoch,
    );
    await _prefs.setInt(_expirationKey(key), expirationTime);
  }

  @override
  Future<T?> getCachedData<T>(String key) async {
    final cachedData = _prefs.getString(_cacheKey(key));
    final timestamp = _prefs.getInt(_timestampKey(key));
    final expiration = _prefs.getInt(_expirationKey(key));

    if (cachedData == null || timestamp == null || expiration == null) {
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > expiration) {
      await remove(key);
      return null;
    }

    try {
      return jsonDecode(cachedData) as T;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cachePrefix) &&
          !key.endsWith(_expirationSuffix) &&
          !key.startsWith(_timestampPrefix)) {
        final cacheKey = key.substring(_cachePrefix.length);
        final timestamp = _prefs.getInt(_timestampKey(cacheKey));
        final expiration = _prefs.getInt(_expirationKey(cacheKey));

        if (timestamp != null &&
            expiration != null &&
            now - timestamp > expiration) {
          await _prefs.remove(_cacheKey(cacheKey));
          await _prefs.remove(_timestampKey(cacheKey));
          await _prefs.remove(_expirationKey(cacheKey));
        }
      }
    }
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    await _prefs.setString('api_base_url', url);
  }

  @override
  Future<String?> getApiBaseUrl() async {
    return _prefs.getString('api_base_url');
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    await _prefs.setString('server_base_url', url);
  }

  @override
  Future<String?> getServerBaseUrl() async {
    return _prefs.getString('server_base_url');
  }
}
