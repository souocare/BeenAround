import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/features/auth/data/session_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

Map<String, dynamic> userResponse() => {
  'id': 'user-1',
  'username': 'goncalo',
  'display_name': 'Gonçalo',
  'is_admin': true,
};

ApiClient createClient(ResponseBody Function(RequestOptions options) handler) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio();
  dio.httpClientAdapter = FakeHttpAdapter(handler);

  return ApiClient(serverConfig: config, dio: dio);
}

void main() {
  group('Web session repository', () {
    test('GET /auth/me returns authenticated user', () async {
      final client = createClient((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/auth/me');

        return jsonResponse(userResponse());
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: true);

      final user = await repository.getCurrentUser();

      expect(user.username, 'goncalo');
      expect(user.displayName, 'Gonçalo');
      expect(user.isAdmin, isTrue);
    });

    test('POST /auth/logout uses Web endpoint', () async {
      final client = createClient((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/auth/logout');

        return ResponseBody.fromString('', 204);
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: true);

      await repository.logout();
    });

    test('401 maps to unauthorized', () async {
      final client = createClient((options) {
        return jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401);
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: true);

      await expectLater(
        repository.getCurrentUser(),
        throwsA(
          isA<SessionException>().having(
            (error) => error.failure,
            'failure',
            SessionFailure.unauthorized,
          ),
        ),
      );
    });
  });

  group('Mobile session repository', () {
    test('GET /auth/mobile/me sends Bearer token', () async {
      final client = createClient((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/auth/mobile/me');
        expect(options.headers['Authorization'], 'Bearer access-token-1');

        return jsonResponse(userResponse());
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      final user = await repository.getCurrentUser(
        accessToken: 'access-token-1',
      );

      expect(user.username, 'goncalo');
    });

    test('refresh rotates mobile credentials', () async {
      final client = createClient((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/auth/mobile/refresh');

        final body = options.data as Map<String, dynamic>;

        expect(body['refresh_token'], 'old-refresh-token');

        return jsonResponse({
          'access_token': 'new-access-token',
          'refresh_token': 'new-refresh-token',
          'token_type': 'bearer',
          'expires_in': 900,
        });
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      final session = await repository.refreshMobileSession(
        'old-refresh-token',
      );

      expect(session.accessToken, 'new-access-token');
      expect(session.refreshToken, 'new-refresh-token');
      expect(session.expiresIn, 900);
    });

    test('POST /auth/mobile/logout sends refresh token', () async {
      final client = createClient((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/auth/mobile/logout');

        final body = options.data as Map<String, dynamic>;

        expect(body['refresh_token'], 'refresh-token-1');

        return ResponseBody.fromString('', 204);
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      await repository.logout(refreshToken: 'refresh-token-1');
    });

    test('401 refresh maps to unauthorized', () async {
      final client = createClient((options) {
        return jsonResponse({
          'detail': 'Invalid refresh token.',
        }, statusCode: 401);
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      await expectLater(
        repository.refreshMobileSession('invalid-token'),
        throwsA(
          isA<SessionException>().having(
            (error) => error.failure,
            'failure',
            SessionFailure.unauthorized,
          ),
        ),
      );
    });

    test('rejects malformed refresh response', () async {
      final client = createClient((options) {
        return jsonResponse({
          'access_token': 'access-token',
          'expires_in': 900,
        });
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      await expectLater(
        repository.refreshMobileSession('refresh-token'),
        throwsA(
          isA<SessionException>().having(
            (error) => error.failure,
            'failure',
            SessionFailure.unexpected,
          ),
        ),
      );
    });
    test('rejects missing access token without making HTTP request', () async {
      var requestCount = 0;

      final client = createClient((options) {
        requestCount++;
        return jsonResponse(userResponse());
      });

      final repository = ApiSessionRepository(apiClient: client, isWeb: false);

      await expectLater(
        repository.getCurrentUser(),
        throwsA(
          isA<SessionException>().having(
            (error) => error.failure,
            'failure',
            SessionFailure.unauthorized,
          ),
        ),
      );

      expect(requestCount, 0);
    });
  });
}
