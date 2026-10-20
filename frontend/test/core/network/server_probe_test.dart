import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/server_probe.dart';
import 'package:beenaround/core/network/server_probe_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter({required this.responses});

  final Map<String, FakeResponse> responses;

  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.uri.path);

    final response = responses[options.uri.path];

    if (response == null) {
      return ResponseBody.fromString('Not Found', 404);
    }

    return ResponseBody.fromString(
      response.rawBody ?? jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeResponse {
  const FakeResponse({
    required this.statusCode,
    required this.body,
    this.rawBody,
  });

  final int statusCode;
  final Object? body;
  final String? rawBody;
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.errorType);

  final DioExceptionType errorType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: errorType);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ServerProbe', () {
    late ApiClient client;
    late FakeServerAdapter adapter;
    late ServerProbe probe;

    void configureProbe(Map<String, FakeResponse> responses) {
      final config = ServerConfig.parse('https://travel.example.com')!;

      client = ApiClient(serverConfig: config);

      adapter = FakeServerAdapter(responses: responses);

      client.dio.httpClientAdapter = adapter;

      probe = ServerProbe(apiClient: client);
    }

    test('returns ready when setup is complete', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: {'status': 'healthy'},
        ),
        '/api/v1/setup/status': const FakeResponse(
          statusCode: 200,
          body: {'setup_required': false},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.ready);
      expect(result.isCompatible, isTrue);

      expect(adapter.requestedPaths, [
        '/api/v1/health',
        '/api/v1/setup/status',
      ]);
    });

    test('returns setupRequired for a new installation', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: {'status': 'healthy'},
        ),
        '/api/v1/setup/status': const FakeResponse(
          statusCode: 200,
          body: {'setup_required': true},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.setupRequired);
      expect(result.isCompatible, isTrue);
    });

    test('rejects an incompatible health response', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: {'status': 'ok'},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.incompatible);

      expect(adapter.requestedPaths, ['/api/v1/health']);
    });

    test('rejects an invalid setup response', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: {'status': 'healthy'},
        ),
        '/api/v1/setup/status': const FakeResponse(
          statusCode: 200,
          body: {'setup_required': 'false'},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.incompatible);
    });

    test('rejects a missing setup status endpoint', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: {'status': 'healthy'},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.incompatible);
    });

    test('returns unavailable for server errors', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 503,
          body: {'detail': 'Service unavailable'},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.unavailable);
    });

    test('rejects an unrelated HTTP service', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 404,
          body: {'detail': 'Not Found'},
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.incompatible);
    });
    test('returns unavailable when the connection fails', () async {
      configureProbe({});

      client.dio.httpClientAdapter = _FailingAdapter(
        DioExceptionType.connectionError,
      );

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.unavailable);
    });

    test('returns unavailable when the connection times out', () async {
      configureProbe({});

      client.dio.httpClientAdapter = _FailingAdapter(
        DioExceptionType.connectionTimeout,
      );

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.unavailable);
    });
    test('returns incompatible for malformed JSON', () async {
      configureProbe({
        '/api/v1/health': const FakeResponse(
          statusCode: 200,
          body: null,
          rawBody: '{invalid-json',
        ),
      });

      final result = await probe.check();

      expect(result.status, ServerProbeStatus.incompatible);
    });
  });
}
