import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;

    return ResponseBody.fromString(
      jsonEncode({'status': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient HTTP', () {
    late ApiClient client;
    late FakeHttpClientAdapter adapter;

    setUp(() {
      final config = ServerConfig.parse('https://travel.example.com')!;

      adapter = FakeHttpClientAdapter();

      client = ApiClient(serverConfig: config);

      client.dio.httpClientAdapter = adapter;
    });

    test('sends requests to the configured API base URL', () async {
      await client.dio.get<Map<String, dynamic>>('health');

      expect(
        adapter.lastRequest?.uri.toString(),
        'https://travel.example.com/api/v1/health',
      );
    });

    test('decodes JSON responses', () async {
      final response = await client.dio.get<Map<String, dynamic>>('health');

      expect(response.statusCode, 200);
      expect(response.data, {'status': 'ok'});
    });

    test('sends the JSON Accept header', () async {
      await client.dio.get<Map<String, dynamic>>('health');

      expect(adapter.lastRequest?.headers['Accept'], 'application/json');
    });
  });
}
