import 'package:beenaround/core/network/auth_interceptor.dart';
import 'package:beenaround/features/auth/application/auth_cubit.dart';
import 'package:dio/dio.dart';

import '../config/server_config.dart';

class ApiClient {
  ApiClient({required ServerConfig serverConfig, Dio? dio})
    : _dio = dio ?? Dio() {
    _dio.options.baseUrl = serverConfig.apiBaseUrl.toString();
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 15);
    _dio.options.headers['Accept'] = 'application/json';
  }

  final Dio _dio;

  Dio get dio => _dio;

  void configureAuthentication({
    required AuthCubit authCubit,
    required bool isWeb,
  }) {
    if (_dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      throw StateError('Authentication is already configured.');
    }

    _dio.interceptors.add(
      AuthInterceptor(dio: _dio, authCubit: authCubit, isWeb: isWeb),
    );
  }
}
