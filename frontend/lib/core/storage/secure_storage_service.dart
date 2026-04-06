import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;

abstract class SecureStorageService {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();

  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();

  Future<void> saveUserId(String userId);
  Future<String?> getUserId();

  Future<void> saveTokenExpiry(DateTime expiry);
  Future<DateTime?> getTokenExpiry();
  Future<void> clearTokenExpiry();

  Future<void> clearTokens();
  Future<void> clearAll();

  Future<void> save(String key, String value);
  Future<String?> get(String key);
  Future<void> remove(String key);
  Future<bool> containsKey(String key);
}

class SecureStorageServiceImpl implements SecureStorageService {

  SecureStorageServiceImpl(this._secureStorage);
  final FlutterSecureStorage _secureStorage;

  static const String _accessTokenKey = config.AppConstants.accessTokenKey;
  static const String _refreshTokenKey = config.AppConstants.refreshTokenKey;
  static const String _userIdKey = 'user_id';
  static const String _tokenExpiryKey = config.AppConstants.tokenExpiryKey;

  @override
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: _userIdKey, value: userId);
  }

  @override
  Future<String?> getUserId() async {
    return _secureStorage.read(key: _userIdKey);
  }

  @override
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _secureStorage.write(
      key: _tokenExpiryKey,
      value: expiry.toIso8601String(),
    );
  }

  @override
  Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
    if (expiryString != null) {
      return DateTime.tryParse(expiryString);
    }
    return null;
  }

  @override
  Future<void> clearTokenExpiry() async {
    await _secureStorage.delete(key: _tokenExpiryKey);
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
  }

  @override
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  @override
  Future<void> save(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> get(String key) async {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> remove(String key) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<bool> containsKey(String key) async {
    final value = await _secureStorage.read(key: key);
    return value != null;
  }
}
