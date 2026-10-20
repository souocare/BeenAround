import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/authenticated_user.dart';

class LoginResult {
  const LoginResult({
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  final AuthenticatedUser user;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

enum LoginFailure { invalidCredentials, unavailable, unexpected }

class LoginException implements Exception {
  const LoginException(this.failure);

  final LoginFailure failure;
}

abstract interface class LoginRepository {
  Future<LoginResult> login({required String login, required String password});
}

class ApiLoginRepository implements LoginRepository {
  const ApiLoginRepository({required this.apiClient, required this.isWeb});

  final ApiClient apiClient;
  final bool isWeb;

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        isWeb ? 'auth/login' : 'auth/mobile/login',
        data: {'login': login.trim(), 'password': password},
      );

      final data = response.data;

      if (data == null) {
        throw const LoginException(LoginFailure.unexpected);
      }

      final user = AuthenticatedUser.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );

      if (isWeb) {
        return LoginResult(user: user);
      }

      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final expiresIn = data['expires_in'];

      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty ||
          expiresIn is! int ||
          expiresIn <= 0) {
        throw const LoginException(LoginFailure.unexpected);
      }

      return LoginResult(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const LoginException(LoginFailure.invalidCredentials);
      }

      if (error.response == null || error.response?.statusCode == 503) {
        throw const LoginException(LoginFailure.unavailable);
      }

      throw const LoginException(LoginFailure.unexpected);
    } on LoginException {
      rethrow;
    } catch (_) {
      throw const LoginException(LoginFailure.unexpected);
    }
  }
}
