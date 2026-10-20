import 'package:dio/dio.dart';

import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/data/session_repository.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required AuthCubit authCubit,
    required bool isWeb,
  }) : _dio = dio,
       _authCubit = authCubit,
       _isWeb = isWeb;

  final Dio _dio;
  final AuthCubit _authCubit;
  final bool _isWeb;

  static const _retryKey = 'beenaround.auth.retried';
  static const _generationKey = 'beenaround.auth.generation';

  static const _excludedPaths = {
    'auth/login',
    'auth/mobile/login',
    'auth/mobile/refresh',
    'auth/mobile/logout',
    'auth/logout',
  };

  bool _isExcluded(RequestOptions options) {
    final path = options.uri.path;

    return _excludedPaths.any((excluded) => path.endsWith('/api/v1/$excluded'));
  }

  bool _canRetry(RequestOptions options) {
    final data = options.data;

    // Multipart uploads and streams cannot be safely replayed.
    if (data is FormData || data is Stream) {
      return false;
    }

    // Only retry requests with supported, replayable bodies.
    return data == null ||
        data is Map ||
        data is List ||
        data is String ||
        data is num ||
        data is bool;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Web authentication uses HttpOnly cookies.
    // Authentication endpoints manage their own credentials.
    if (_isWeb || _isExcluded(options)) {
      handler.next(options);
      return;
    }

    // A retried request already contains its intended authorization.
    // Never replace it with credentials from a different session.
    if (options.extra[_retryKey] == true) {
      handler.next(options);
      return;
    }

    final token = _authCubit.accessToken;

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_generationKey] = _authCubit.sessionGeneration;
    }

    handler.next(options);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;

    // Web authentication is handled through session cookies.
    // Only HTTP 401 responses from protected endpoints are relevant.
    if (_isWeb || error.response?.statusCode != 401 || _isExcluded(options)) {
      handler.next(error);
      return;
    }

    final generation = options.extra[_generationKey];

    // Requests without a known session must not trigger refresh.
    // Responses from older sessions must not affect newer sessions.
    if (generation is! int || generation != _authCubit.sessionGeneration) {
      handler.next(error);
      return;
    }

    // A retried request has also failed with HTTP 401.
    // Do not retry again. Invalidate only the matching session.
    if (options.extra[_retryKey] == true) {
      final authorization = options.headers['Authorization'];
      final currentToken = _authCubit.accessToken;

      if (currentToken != null && authorization == 'Bearer $currentToken') {
        await _authCubit.invalidateSession(expectedGeneration: generation);
      }

      handler.next(error);
      return;
    }

    // Do not refresh if the original request cannot be replayed.
    if (!_canRetry(options)) {
      handler.next(error);
      return;
    }

    final failedAuthorization = options.headers['Authorization'];
    final currentToken = _authCubit.accessToken;

    if (currentToken == null || currentToken.isEmpty) {
      handler.next(error);
      return;
    }

    try {
      // Another request may already have refreshed the access token.
      // Only refresh if the failed request used the current token.
      if (failedAuthorization == 'Bearer $currentToken') {
        await _authCubit.refreshAccessToken();
      }

      // Logout or a new login may have occurred during refresh.
      if (generation != _authCubit.sessionGeneration) {
        handler.next(error);
        return;
      }

      final refreshedToken = _authCubit.accessToken;

      if (refreshedToken == null || refreshedToken.isEmpty) {
        handler.next(error);
        return;
      }

      // Retry exactly once using the current session's access token.
      final retryOptions = options.copyWith(
        headers: {
          ...options.headers,
          'Authorization': 'Bearer $refreshedToken',
        },
        extra: {...options.extra, _retryKey: true},
      );

      final response = await _dio.fetch<dynamic>(retryOptions);

      handler.resolve(response);
    } on SessionException catch (sessionError) {
      // Invalid refresh credentials require local session invalidation.
      // Network failures must preserve the stored refresh token.
      if (sessionError.failure == SessionFailure.unauthorized) {
        await _authCubit.invalidateSession(expectedGeneration: generation);
      }

      handler.next(error);
    } catch (_) {
      // Preserve the original HTTP error.
      handler.next(error);
    }
  }
}
