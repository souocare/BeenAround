import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/authenticated_user.dart';
import '../domain/mobile_session.dart';
import 'secure_token_storage.dart';

enum SessionFailure { unauthorized, unavailable, unexpected }

class SessionException implements Exception {
  const SessionException(this.failure);

  final SessionFailure failure;
}

abstract interface class SessionRepository {
  Future<AuthenticatedUser> getCurrentUser({String? accessToken});

  Future<MobileSession> refreshMobileSession(String refreshToken);

  Future<void> logout({String? refreshToken});
}

class ApiSessionRepository implements SessionRepository {
  const ApiSessionRepository({required this.apiClient, required this.isWeb});

  final ApiClient apiClient;
  final bool isWeb;

  @override
  Future<AuthenticatedUser> getCurrentUser({String? accessToken}) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        isWeb ? 'auth/me' : 'auth/mobile/me',
        options: Options(
          headers: isWeb ? null : {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final data = response.data;

      if (data == null) {
        throw const SessionException(SessionFailure.unexpected);
      }

      return AuthenticatedUser.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    } on SessionException {
      rethrow;
    } catch (_) {
      throw const SessionException(SessionFailure.unexpected);
    }
  }

  @override
  Future<MobileSession> refreshMobileSession(String refreshToken) async {
    if (isWeb) {
      throw const SessionException(SessionFailure.unexpected);
    }

    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'auth/mobile/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;

      if (data == null) {
        throw const SessionException(SessionFailure.unexpected);
      }

      final accessToken = data['access_token'];
      final newRefreshToken = data['refresh_token'];
      final expiresIn = data['expires_in'];

      if (accessToken is! String ||
          accessToken.isEmpty ||
          newRefreshToken is! String ||
          newRefreshToken.isEmpty ||
          expiresIn is! int ||
          expiresIn <= 0) {
        throw const SessionException(SessionFailure.unexpected);
      }

      return MobileSession(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    } on SessionException {
      rethrow;
    } catch (_) {
      throw const SessionException(SessionFailure.unexpected);
    }
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    try {
      if (isWeb) {
        await apiClient.dio.post<void>('auth/logout');
      } else {
        if (refreshToken == null || refreshToken.isEmpty) {
          throw const SessionException(SessionFailure.unexpected);
        }

        await apiClient.dio.post<void>(
          'auth/mobile/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  SessionException _mapError(DioException error) {
    if (error.response?.statusCode == 401) {
      return const SessionException(SessionFailure.unauthorized);
    }

    if (error.response == null || error.response?.statusCode == 503) {
      return const SessionException(SessionFailure.unavailable);
    }

    return const SessionException(SessionFailure.unexpected);
  }
}
