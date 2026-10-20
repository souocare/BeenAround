import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/config/server_config.dart';

void main() {
  group('ServerConfig', () {
    test('accepts a valid HTTPS server', () {
      final config = ServerConfig.parse('https://travel.example.com');

      expect(config, isNotNull);
      expect(config!.baseUrl.toString(), 'https://travel.example.com');
    });

    test('normalizes whitespace and trailing slash', () {
      final config = ServerConfig.parse('  https://travel.example.com/  ');

      expect(config, isNotNull);
      expect(config!.baseUrl.toString(), 'https://travel.example.com');
    });

    test('creates the API base URL', () {
      final config = ServerConfig.parse('https://travel.example.com');

      expect(
        config!.apiBaseUrl.toString(),
        'https://travel.example.com/api/v1/',
      );
    });

    test('allows HTTP when explicitly enabled', () {
      final config = ServerConfig.parse('http://192.168.1.100:8000');

      expect(config, isNotNull);
    });

    test('rejects unsupported schemes', () {
      expect(ServerConfig.parse('ftp://travel.example.com'), isNull);
    });

    test('rejects credentials embedded in URL', () {
      expect(
        ServerConfig.parse('https://user:password@travel.example.com'),
        isNull,
      );
    });

    test('rejects API paths', () {
      expect(ServerConfig.parse('https://travel.example.com/api/v1'), isNull);
    });

    test('rejects query parameters', () {
      expect(
        ServerConfig.parse('https://travel.example.com?token=123'),
        isNull,
      );
    });

    test('rejects empty input', () {
      expect(ServerConfig.parse(''), isNull);
    });
  });
}
