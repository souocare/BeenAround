import 'dart:async';

import 'package:beenaround/features/auth/application/auth_cubit.dart';
import 'package:beenaround/features/auth/application/auth_state.dart';
import 'package:beenaround/features/auth/data/login_repository.dart';
import 'package:beenaround/features/auth/data/secure_token_storage.dart';
import 'package:beenaround/features/auth/data/session_repository.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:beenaround/features/auth/domain/mobile_session.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthenticatedUser(
  id: 'user-1',
  username: 'goncalo',
  displayName: 'Gonçalo',
  isAdmin: true,
);

class FakeTokenStorage implements SecureTokenStorage {
  String? token;
  bool failWrites = false;
  Completer<void>? writeCompleter;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String value) async {
    if (failWrites) {
      throw StateError('Secure storage unavailable');
    }

    if (writeCompleter != null) {
      await writeCompleter!.future;
    }

    token = value;
  }

  @override
  Future<void> deleteRefreshToken() async {
    token = null;
  }
}

class FakeSessionRepository implements SessionRepository {
  AuthenticatedUser? currentUser = testUser;
  SessionException? currentUserError;
  SessionException? refreshError;
  SessionException? logoutError;

  MobileSession refreshedSession = const MobileSession(
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    expiresIn: 900,
  );

  Completer<MobileSession>? refreshCompleter;

  int refreshCalls = 0;
  int logoutCalls = 0;

  String? lastAccessToken;
  String? lastRefreshToken;

  @override
  Future<AuthenticatedUser> getCurrentUser({String? accessToken}) async {
    lastAccessToken = accessToken;

    if (currentUserError != null) {
      throw currentUserError!;
    }

    return currentUser!;
  }

  @override
  Future<MobileSession> refreshMobileSession(String refreshToken) async {
    refreshCalls++;
    lastRefreshToken = refreshToken;

    if (refreshError != null) {
      throw refreshError!;
    }

    if (refreshCompleter != null) {
      return refreshCompleter!.future;
    }

    return refreshedSession;
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutCalls++;
    lastRefreshToken = refreshToken;

    if (logoutError != null) {
      throw logoutError!;
    }
  }
}

void main() {
  late FakeSessionRepository repository;
  late FakeTokenStorage storage;

  setUp(() {
    repository = FakeSessionRepository();
    storage = FakeTokenStorage();
  });

  AuthCubit createMobileCubit() => AuthCubit(
    sessionRepository: repository,
    tokenStorage: storage,
    isWeb: false,
  );

  AuthCubit createWebCubit() =>
      AuthCubit(sessionRepository: repository, tokenStorage: null, isWeb: true);

  group('Web authentication', () {
    test('restores valid Web session', () async {
      final cubit = createWebCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.authenticated);
      expect(cubit.state.user?.username, 'goncalo');
    });

    test('401 results in unauthenticated state', () async {
      repository.currentUserError = const SessionException(
        SessionFailure.unauthorized,
      );

      final cubit = createWebCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.unauthenticated);
    });

    test('network failure preserves retryable state', () async {
      repository.currentUserError = const SessionException(
        SessionFailure.unavailable,
      );

      final cubit = createWebCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.unavailable);
    });

    test('accepts successful Web login', () async {
      final cubit = createWebCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(const LoginResult(user: testUser));

      expect(cubit.state.phase, AuthPhase.authenticated);
    });
  });

  group('Mobile authentication', () {
    test('without stored token remains unauthenticated', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.unauthenticated);
      expect(repository.refreshCalls, 0);
    });

    test('restores session and persists rotated token', () async {
      storage.token = 'old-refresh';

      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(repository.refreshCalls, 1);
      expect(repository.lastRefreshToken, 'old-refresh');
      expect(storage.token, 'new-refresh');
      expect(cubit.accessToken, 'new-access');
      expect(repository.lastAccessToken, 'new-access');
      expect(cubit.state.phase, AuthPhase.authenticated);
    });

    test('invalid refresh token clears stored credentials', () async {
      storage.token = 'expired-refresh';

      repository.refreshError = const SessionException(
        SessionFailure.unauthorized,
      );

      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.unauthenticated);
      expect(storage.token, isNull);
      expect(cubit.accessToken, isNull);
    });

    test('network failure preserves stored refresh token', () async {
      storage.token = 'valid-refresh';

      repository.refreshError = const SessionException(
        SessionFailure.unavailable,
      );

      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.restoreSession();

      expect(cubit.state.phase, AuthPhase.unavailable);
      expect(storage.token, 'valid-refresh');
    });

    test('accepts login and stores refresh token', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          expiresIn: 900,
        ),
      );

      expect(storage.token, 'login-refresh');
      expect(cubit.accessToken, 'login-access');
      expect(cubit.state.phase, AuthPhase.authenticated);
    });

    test('concurrent refresh requests share one HTTP operation', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          expiresIn: 900,
        ),
      );

      final completer = Completer<MobileSession>();
      repository.refreshCompleter = completer;

      final first = cubit.refreshAccessToken();
      final second = cubit.refreshAccessToken();

      expect(repository.refreshCalls, 1);

      completer.complete(
        const MobileSession(
          accessToken: 'rotated-access',
          refreshToken: 'rotated-refresh',
          expiresIn: 900,
        ),
      );

      final results = await Future.wait([first, second]);

      expect(results[0].refreshToken, 'rotated-refresh');
      expect(results[1].refreshToken, 'rotated-refresh');
      expect(repository.refreshCalls, 1);
      expect(storage.token, 'rotated-refresh');
    });

    test('logout clears credentials', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          expiresIn: 900,
        ),
      );

      await cubit.logout();

      expect(repository.logoutCalls, 1);
      expect(repository.lastRefreshToken, 'login-refresh');
      expect(storage.token, isNull);
      expect(cubit.accessToken, isNull);
      expect(cubit.state.phase, AuthPhase.unauthenticated);
    });

    test('logout clears locally even when server is unavailable', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          expiresIn: 900,
        ),
      );

      repository.logoutError = const SessionException(
        SessionFailure.unavailable,
      );

      await cubit.logout();

      expect(storage.token, isNull);
      expect(cubit.state.phase, AuthPhase.unauthenticated);
    });
    test('logout during refresh never restores credentials', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'initial-access',
          refreshToken: 'initial-refresh',
          expiresIn: 900,
        ),
      );

      final completer = Completer<MobileSession>();
      repository.refreshCompleter = completer;

      final refreshFuture = cubit.refreshAccessToken();

      expect(repository.refreshCalls, 1);

      await cubit.logout();

      completer.complete(
        const MobileSession(
          accessToken: 'rotated-access',
          refreshToken: 'rotated-refresh',
          expiresIn: 900,
        ),
      );

      await expectLater(refreshFuture, throwsA(isA<SessionException>()));

      expect(cubit.state.phase, AuthPhase.unauthenticated);
      expect(cubit.accessToken, isNull);
      expect(storage.token, isNull);
    });
    test('concurrent restores share one operation', () async {
      storage.token = 'stored-refresh';

      final completer = Completer<MobileSession>();
      repository.refreshCompleter = completer;

      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      final first = cubit.restoreSession();
      final second = cubit.restoreSession();

      await Future<void>.delayed(Duration.zero);

      expect(repository.refreshCalls, 1);

      completer.complete(
        const MobileSession(
          accessToken: 'restored-access',
          refreshToken: 'restored-refresh',
          expiresIn: 900,
        ),
      );

      await Future.wait([first, second]);

      expect(repository.refreshCalls, 1);
      expect(cubit.state.phase, AuthPhase.authenticated);
      expect(storage.token, 'restored-refresh');
    });
    test('failed rotated-token write never exposes new access token', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      await cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'initial-access',
          refreshToken: 'initial-refresh',
          expiresIn: 900,
        ),
      );

      storage.failWrites = true;

      await expectLater(
        cubit.refreshAccessToken(),
        throwsA(
          isA<SessionException>().having(
            (error) => error.failure,
            'failure',
            SessionFailure.unexpected,
          ),
        ),
      );

      expect(cubit.accessToken, isNull);
      expect(storage.token, 'initial-refresh');
    });
    test('logout during login does not restore credentials', () async {
      final cubit = createMobileCubit();
      addTearDown(cubit.close);

      final completer = Completer<void>();
      storage.writeCompleter = completer;

      final loginFuture = cubit.acceptLogin(
        const LoginResult(
          user: testUser,
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          expiresIn: 900,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final logoutFuture = cubit.logout();

      completer.complete();

      await Future.wait([loginFuture, logoutFuture]);

      expect(cubit.state.phase, AuthPhase.unauthenticated);
      expect(cubit.accessToken, isNull);
      expect(storage.token, isNull);
    });
  });
}
