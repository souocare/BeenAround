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
}
