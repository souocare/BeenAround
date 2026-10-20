import 'package:beenaround/features/auth/data/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemorySecureTokenStorage implements SecureTokenStorage {
  String? token;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteRefreshToken() async {
    token = null;
  }
}

void main() {
  late InMemorySecureTokenStorage storage;

  setUp(() {
    storage = InMemorySecureTokenStorage();
  });

  test('returns null when no token exists', () async {
    expect(await storage.readRefreshToken(), isNull);
  });

  test('stores and retrieves refresh token', () async {
    await storage.writeRefreshToken('refresh-token-1');

    expect(await storage.readRefreshToken(), 'refresh-token-1');
  });

  test('replaces existing refresh token', () async {
    await storage.writeRefreshToken('refresh-token-1');
    await storage.writeRefreshToken('refresh-token-2');

    expect(await storage.readRefreshToken(), 'refresh-token-2');
  });

  test('deletes stored refresh token', () async {
    await storage.writeRefreshToken('refresh-token-1');
    await storage.deleteRefreshToken();

    expect(await storage.readRefreshToken(), isNull);
  });
  test('refresh tokens are isolated by server origin', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final firstServer = FlutterSecureTokenStorage(
      serverOrigin: Uri.parse('https://travel.example.com'),
    );

    final secondServer = FlutterSecureTokenStorage(
      serverOrigin: Uri.parse('https://other.example.com'),
    );

    await firstServer.writeRefreshToken('token-server-a');

    expect(await firstServer.readRefreshToken(), 'token-server-a');

    expect(await secondServer.readRefreshToken(), isNull);

    await secondServer.writeRefreshToken('token-server-b');

    expect(await firstServer.readRefreshToken(), 'token-server-a');

    expect(await secondServer.readRefreshToken(), 'token-server-b');

    await firstServer.deleteRefreshToken();

    expect(await firstServer.readRefreshToken(), isNull);
    expect(await secondServer.readRefreshToken(), 'token-server-b');
  });
}
