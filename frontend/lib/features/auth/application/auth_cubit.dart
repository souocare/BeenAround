import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/login_repository.dart';
import '../data/secure_token_storage.dart';
import '../data/session_repository.dart';
import '../domain/mobile_session.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required SessionRepository sessionRepository,
    required SecureTokenStorage? tokenStorage,
    required bool isWeb,
  }) : _sessionRepository = sessionRepository,
       _tokenStorage = tokenStorage,
       _isWeb = isWeb,
       super(const AuthState());

  final SessionRepository _sessionRepository;
  final SecureTokenStorage? _tokenStorage;
  final bool _isWeb;

  String? _accessToken;
  String? _refreshToken;

  Future<void>? _restoreInProgress;
  Future<MobileSession>? _refreshInProgress;
  Future<void>? _logoutInProgress;

  Future<void> _storageOperation = Future<void>.value();

  int _sessionGeneration = 0;

  String? get accessToken => _accessToken;
  int get sessionGeneration => _sessionGeneration;

  bool _isCurrent(int generation) {
    return !isClosed && generation == _sessionGeneration;
  }

  Future<T> _withStorageLock<T>(Future<T> Function() operation) async {
    final previous = _storageOperation;
    final completed = Completer<void>();

    _storageOperation = completed.future;

    try {
      await previous;
      return await operation();
    } finally {
      completed.complete();
    }
  }

  Future<void> restoreSession() {
    if (isClosed) return Future<void>.value();

    final existing = _restoreInProgress;

    if (existing != null) return existing;

    final generation = _sessionGeneration;
    final future = _performRestore(generation);

    _restoreInProgress = future;

    return future.whenComplete(() {
      if (identical(_restoreInProgress, future)) {
        _restoreInProgress = null;
      }
    });
  }

  Future<void> _performRestore(int generation) async {
    if (!_isCurrent(generation)) return;

    emit(const AuthState(phase: AuthPhase.restoring));

    try {
      if (_isWeb) {
        final user = await _sessionRepository.getCurrentUser();

        if (!_isCurrent(generation)) return;

        emit(AuthState(phase: AuthPhase.authenticated, user: user));
        return;
      }

      final storage = _tokenStorage;

      if (storage == null) {
        if (_isCurrent(generation)) {
          emit(const AuthState(phase: AuthPhase.unauthenticated));
        }
        return;
      }

      final storedToken = await _withStorageLock(storage.readRefreshToken);

      if (!_isCurrent(generation)) return;

      if (storedToken == null || storedToken.isEmpty) {
        emit(const AuthState(phase: AuthPhase.unauthenticated));
        return;
      }

      _refreshToken = storedToken;

      final session = await refreshAccessToken();

      if (!_isCurrent(generation)) return;

      final user = await _sessionRepository.getCurrentUser(
        accessToken: session.accessToken,
      );

      if (!_isCurrent(generation)) return;

      emit(AuthState(phase: AuthPhase.authenticated, user: user));
    } on SessionException catch (error) {
      if (!_isCurrent(generation)) return;

      if (error.failure == SessionFailure.unauthorized) {
        await _invalidateSession(generation);
      } else {
        emit(const AuthState(phase: AuthPhase.unavailable));
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        emit(const AuthState(phase: AuthPhase.unavailable));
      }
    }
  }

  Future<void> invalidateSession({required int expectedGeneration}) async {
    if (!_isCurrent(expectedGeneration)) return;

    final generation = ++_sessionGeneration;

    _accessToken = null;
    _refreshToken = null;

    await _withStorageLock(() async {
      if (!_isCurrent(generation)) return;

      await _tokenStorage?.deleteRefreshToken();
    });

    if (_isCurrent(generation)) {
      emit(const AuthState(phase: AuthPhase.unauthenticated));
    }
  }

  Future<void> acceptLogin(LoginResult result) async {
    if (isClosed) return;

    final generation = ++_sessionGeneration;

    if (_isWeb) {
      emit(AuthState(phase: AuthPhase.authenticated, user: result.user));
      return;
    }

    final storage = _tokenStorage;

    if (storage == null ||
        result.accessToken == null ||
        result.refreshToken == null ||
        result.accessToken!.isEmpty ||
        result.refreshToken!.isEmpty) {
      throw StateError('Invalid mobile login credentials.');
    }

    await _withStorageLock(() async {
      if (!_isCurrent(generation)) return;

      await storage.writeRefreshToken(result.refreshToken!);
    });

    if (!_isCurrent(generation)) return;

    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;

    emit(AuthState(phase: AuthPhase.authenticated, user: result.user));
  }

  Future<MobileSession> refreshAccessToken() {
    if (_isWeb) {
      throw StateError('Mobile refresh is not available on Web.');
    }

    if (isClosed) {
      throw StateError('AuthCubit is closed.');
    }

    final existing = _refreshInProgress;

    if (existing != null) return existing;

    final generation = _sessionGeneration;
    final future = _performRefresh(generation);

    _refreshInProgress = future;

    return future.whenComplete(() {
      if (identical(_refreshInProgress, future)) {
        _refreshInProgress = null;
      }
    });
  }

  Future<MobileSession> _performRefresh(int generation) async {
    final refreshToken = _refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionException(SessionFailure.unauthorized);
    }

    final session = await _sessionRepository.refreshMobileSession(refreshToken);

    if (!_isCurrent(generation)) {
      throw const SessionException(SessionFailure.unauthorized);
    }

    final storage = _tokenStorage;

    if (storage == null) {
      throw const SessionException(SessionFailure.unexpected);
    }

    try {
      await _withStorageLock(() async {
        if (!_isCurrent(generation)) return;

        await storage.writeRefreshToken(session.refreshToken);
      });
    } catch (_) {
      // The backend may already have invalidated the previous refresh token.
      // Never continue using credentials from that session.
      if (_isCurrent(generation)) {
        _accessToken = null;
        _refreshToken = null;
      }

      throw const SessionException(SessionFailure.unexpected);
    }

    if (!_isCurrent(generation)) {
      throw const SessionException(SessionFailure.unauthorized);
    }

    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;

    return session;
  }

  Future<void> _invalidateSession(int generation) async {
    if (!_isCurrent(generation)) return;

    ++_sessionGeneration;

    await _clearLocalSession();

    if (!isClosed) {
      emit(const AuthState(phase: AuthPhase.unauthenticated));
    }
  }

  Future<void> logout() {
    final existing = _logoutInProgress;

    if (existing != null) return existing;

    if (isClosed) return Future<void>.value();

    final generation = ++_sessionGeneration;
    final refreshToken = _refreshToken;

    // Immediately prevent new requests from using the old credentials.
    _accessToken = null;
    _refreshToken = null;

    final future = _performLogout(
      refreshToken: refreshToken,
      generation: generation,
    );

    _logoutInProgress = future;

    return future.whenComplete(() {
      if (identical(_logoutInProgress, future)) {
        _logoutInProgress = null;
      }
    });
  }

  Future<void> _performLogout({
    required String? refreshToken,
    required int generation,
  }) async {
    try {
      await _sessionRepository.logout(
        refreshToken: _isWeb ? null : refreshToken,
      );
    } on SessionException {
      // Local logout must complete even if the server is unavailable.
    } finally {
      await _withStorageLock(() async {
        if (!_isCurrent(generation)) return;

        await _tokenStorage?.deleteRefreshToken();
      });

      if (_isCurrent(generation)) {
        emit(const AuthState(phase: AuthPhase.unauthenticated));
      }
    }
  }

  Future<void> _clearLocalSession() async {
    _accessToken = null;
    _refreshToken = null;

    if (_isWeb) return;

    final storage = _tokenStorage;

    if (storage == null) return;

    await _withStorageLock(storage.deleteRefreshToken);
  }
}
