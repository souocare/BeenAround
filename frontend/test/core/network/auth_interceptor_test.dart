import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/features/auth/application/auth_cubit.dart';
import 'package:beenaround/features/auth/application/auth_state.dart';
import 'package:beenaround/features/auth/data/login_repository.dart';
import 'package:beenaround/features/auth/data/secure_token_storage.dart';
import 'package:beenaround/features/auth/data/session_repository.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:beenaround/features/auth/domain/mobile_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthenticatedUser(
  id: 'user-1',
  username: 'goncalo',
  displayName: 'Gonçalo',
  isAdmin: true,
);

class FakeTokenStorage implements SecureTokenStorage {
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

class FakeSessionRepository implements SessionRepository {
  int refreshCalls = 0;
  SessionException? refreshError;

  @override
  Future<AuthenticatedUser> getCurrentUser({String? accessToken}) async {
    return testUser;
  }

  @override
  Future<MobileSession> refreshMobileSession(String refreshToken) async {
    refreshCalls++;

    if (refreshError != null) {
      throw refreshError!;
    }

    return const MobileSession(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresIn: 900,
    );
  }

  @override
  Future<void> logout({String? refreshToken}) async {}
}

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return await handler(options);
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

void main() {
  late FakeTokenStorage storage;
  late FakeSessionRepository repository;

  setUp(() {
    storage = FakeTokenStorage();
    repository = FakeSessionRepository();
  });

  Future<(ApiClient, AuthCubit)> createClient({
    required bool isWeb,
    required FutureOr<ResponseBody> Function(RequestOptions options) handler,
  }) async {
    final config = ServerConfig.parse('https://travel.example.com')!;

    final dio = Dio();
    dio.httpClientAdapter = FakeHttpAdapter(handler);

    final apiClient = ApiClient(serverConfig: config, dio: dio);

    final cubit = AuthCubit(
      sessionRepository: repository,
      tokenStorage: isWeb ? null : storage,
      isWeb: isWeb,
    );

    apiClient.configureAuthentication(authCubit: cubit, isWeb: isWeb);

    if (!isWeb) {
      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          expiresIn: 900,
        ),
      );
    }

    return (apiClient, cubit);
  }

  test('Mobile adds Bearer token to protected requests', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        expect(options.uri.path, '/api/v1/trips');
        expect(options.headers['Authorization'], 'Bearer old-access');

        return jsonResponse({'items': []});
      },
    );

    addTearDown(cubit.close);

    await client.dio.get<Map<String, dynamic>>('trips');

    expect(repository.refreshCalls, 0);
  });

  test('Web does not add Bearer token', () async {
    final (client, cubit) = await createClient(
      isWeb: true,
      handler: (options) {
        expect(options.headers.containsKey('Authorization'), isFalse);

        return jsonResponse({'items': []});
      },
    );

    addTearDown(cubit.close);

    await client.dio.get<Map<String, dynamic>>('trips');
  });

  test('Login endpoint does not receive Bearer token', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        expect(options.uri.path, '/api/v1/auth/mobile/login');
        expect(options.headers.containsKey('Authorization'), isFalse);

        return jsonResponse({'ok': true});
      },
    );

    addTearDown(cubit.close);

    await client.dio.post<Map<String, dynamic>>(
      'auth/mobile/login',
      data: {'login': 'goncalo', 'password': 'test-password'},
    );
  });

  test('401 refreshes token and retries request once', () async {
    var requests = 0;

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        requests++;

        if (requests == 1) {
          expect(options.headers['Authorization'], 'Bearer old-access');

          return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
        }

        expect(options.headers['Authorization'], 'Bearer new-access');

        return jsonResponse({'items': []});
      },
    );

    addTearDown(cubit.close);

    final response = await client.dio.get<Map<String, dynamic>>('trips');

    expect(response.statusCode, 200);
    expect(requests, 2);
    expect(repository.refreshCalls, 1);
    expect(storage.token, 'new-refresh');
  });

  test('second 401 does not trigger another refresh', () async {
    var requests = 0;

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) {
        requests++;

        return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
      },
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.get<Map<String, dynamic>>('trips'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(requests, 2);
    expect(repository.refreshCalls, 1);
  });

  test('invalid refresh token invalidates session', () async {
    repository.refreshError = const SessionException(
      SessionFailure.unauthorized,
    );

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) => jsonResponse({'detail': 'Unauthorized'}, statusCode: 401),
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.get<Map<String, dynamic>>('trips'),
      throwsA(isA<DioException>()),
    );

    expect(cubit.state.phase, AuthPhase.unauthenticated);
    expect(cubit.accessToken, isNull);
    expect(storage.token, isNull);
  });

  test('network failure during refresh preserves credentials', () async {
    repository.refreshError = const SessionException(
      SessionFailure.unavailable,
    );

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) => jsonResponse({'detail': 'Unauthorized'}, statusCode: 401),
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.get<Map<String, dynamic>>('trips'),
      throwsA(isA<DioException>()),
    );

    expect(cubit.state.phase, AuthPhase.authenticated);
    expect(storage.token, 'old-refresh');
  });

  test('second 401 invalidates the current session', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) => jsonResponse({'detail': 'Unauthorized'}, statusCode: 401),
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.get<Map<String, dynamic>>('trips'),
      throwsA(isA<DioException>()),
    );

    expect(repository.refreshCalls, 1);
    expect(cubit.state.phase, AuthPhase.unauthenticated);
    expect(cubit.accessToken, isNull);
    expect(storage.token, isNull);
  });

  test('authentication cannot be configured twice', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) => jsonResponse({'items': []}),
    );

    addTearDown(cubit.close);

    expect(
      () => client.configureAuthentication(authCubit: cubit, isWeb: false),
      throwsStateError,
    );
  });
  test('401 from previous login does not invalidate new session', () async {
    final oldRequest = Completer<ResponseBody>();
    final requestStarted = Completer<void>();

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        // Confirm that the request was sent using the old session.
        expect(options.headers['Authorization'], 'Bearer old-access');

        if (!requestStarted.isCompleted) {
          requestStarted.complete();
        }

        return oldRequest.future;
      },
    );

    addTearDown(cubit.close);

    // Start the request using session A.
    final request = client.dio.get<Map<String, dynamic>>('trips');

    // Wait until the HTTP adapter has received the request.
    // This guarantees that the old session generation was captured.
    await requestStarted.future;

    // Replace session A with session B.
    await cubit.acceptLogin(
      const LoginResult(
        user: testUser,
        accessToken: 'second-access',
        refreshToken: 'second-refresh',
        expiresIn: 900,
      ),
    );

    // The old request now receives HTTP 401.
    oldRequest.complete(
      jsonResponse({'detail': 'Unauthorized'}, statusCode: 401),
    );

    await expectLater(request, throwsA(isA<DioException>()));

    // The old response must not refresh or invalidate session B.
    expect(repository.refreshCalls, 0);
    expect(cubit.state.phase, AuthPhase.authenticated);
    expect(cubit.accessToken, 'second-access');
    expect(storage.token, 'second-refresh');
  });
  test('concurrent 401 responses reuse the refreshed token', () async {
    var oldTokenRequests = 0;
    var newTokenRequests = 0;

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        final authorization = options.headers['Authorization'];

        if (authorization == 'Bearer old-access') {
          oldTokenRequests++;

          return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
        }

        if (authorization == 'Bearer new-access') {
          newTokenRequests++;

          return jsonResponse({'items': []});
        }

        return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
      },
    );

    addTearDown(cubit.close);

    final responses = await Future.wait([
      client.dio.get<Map<String, dynamic>>('trips'),
      client.dio.get<Map<String, dynamic>>('countries'),
    ]);

    expect(responses.every((response) => response.statusCode == 200), isTrue);

    expect(oldTokenRequests, 2);
    expect(newTokenRequests, 2);
    expect(repository.refreshCalls, 1);
    expect(storage.token, 'new-refresh');
  });
  test('FormData request is not automatically retried', () async {
    var requests = 0;

    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (_) {
        requests++;

        return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
      },
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.post<Map<String, dynamic>>(
        'uploads',
        data: FormData.fromMap({'file': 'example'}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(requests, 1);
    expect(repository.refreshCalls, 0);
  });
  test('Mobile does not send Bearer token to external origins', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        expect(options.uri.host, 'external.example.com');
        expect(options.headers.containsKey('Authorization'), isFalse);

        return jsonResponse({'ok': true});
      },
    );

    addTearDown(cubit.close);

    await client.dio.get<Map<String, dynamic>>(
      'https://external.example.com/resource',
    );

    expect(repository.refreshCalls, 0);
  });
  test('External 401 does not refresh or invalidate session', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        expect(options.uri.host, 'external.example.com');

        return jsonResponse({'detail': 'Unauthorized'}, statusCode: 401);
      },
    );

    addTearDown(cubit.close);

    await expectLater(
      client.dio.get<Map<String, dynamic>>(
        'https://external.example.com/resource',
      ),
      throwsA(isA<DioException>()),
    );

    expect(repository.refreshCalls, 0);
    expect(cubit.state.phase, AuthPhase.authenticated);
    expect(cubit.accessToken, 'old-access');
    expect(storage.token, 'old-refresh');
  });
  test('Mobile does not send Bearer token outside API path', () async {
    final (client, cubit) = await createClient(
      isWeb: false,
      handler: (options) {
        expect(options.uri.path, '/public/resource');
        expect(options.headers.containsKey('Authorization'), isFalse);

        return jsonResponse({'ok': true});
      },
    );

    addTearDown(cubit.close);

    await client.dio.get<Map<String, dynamic>>(
      'https://travel.example.com/public/resource',
    );
  });
}
