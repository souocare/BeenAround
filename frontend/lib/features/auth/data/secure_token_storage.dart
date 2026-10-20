import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureTokenStorage {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> deleteRefreshToken();
}

class FlutterSecureTokenStorage implements SecureTokenStorage {
  FlutterSecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'beenaround.mobile.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> writeRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> deleteRefreshToken() {
    return _storage.delete(key: _refreshTokenKey);
  }
}
