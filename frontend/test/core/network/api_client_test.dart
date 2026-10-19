import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
    test('uses the configured API base URL', () {
      final config = ServerConfig.parse('https://travel.example.com')!;

      final client = ApiClient(serverConfig: config);

      expect(client.dio.options.baseUrl, 'https://travel.example.com/api/v1/');
    });

    test('configures request timeouts', () {
      final config = ServerConfig.parse('https://travel.example.com')!;

      final client = ApiClient(serverConfig: config);

      expect(client.dio.options.connectTimeout, const Duration(seconds: 10));

      expect(client.dio.options.receiveTimeout, const Duration(seconds: 15));

      expect(client.dio.options.sendTimeout, const Duration(seconds: 15));
    });

    test('accepts JSON responses', () {
      final config = ServerConfig.parse('https://travel.example.com')!;

      final client = ApiClient(serverConfig: config);

      expect(client.dio.options.headers['Accept'], 'application/json');
    });

    test('supports injecting an existing Dio instance', () {
      final config = ServerConfig.parse('https://travel.example.com')!;

      final dio = Dio();

      final client = ApiClient(serverConfig: config, dio: dio);

      expect(identical(client.dio, dio), isTrue);
    });
  });
}
