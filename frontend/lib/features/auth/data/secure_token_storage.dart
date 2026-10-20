import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureTokenStorage {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> deleteRefreshToken();
}

class FlutterSecureTokenStorage implements SecureTokenStorage {
  FlutterSecureTokenStorage({
    required Uri serverOrigin,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _key =
           'beenaround.mobile.refresh_token.${Uri.encodeComponent(serverOrigin.origin)}';

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _key);
  }

  @override
  Future<void> writeRefreshToken(String token) {
    return _storage.write(key: _key, value: token);
  }

  @override
  Future<void> deleteRefreshToken() {
    return _storage.delete(key: _key);
  }
}
