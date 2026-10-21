import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/network/auth_interceptor_test.dart';

class FakeCountriesHttpAdapter implements HttpClientAdapter {
  FakeCountriesHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

ApiCountriesRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;
  final dio = Dio()..httpClientAdapter = FakeCountriesHttpAdapter(handler);

  return ApiCountriesRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('CountriesRepository', () {
    test('loads countries from the configured API', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/countries');

        return jsonResponse({
          'items': [
            {'code': 'PT', 'name': 'Portugal', 'alpha3_code': 'PRT'},
            {'code': 'ES', 'name': 'Spain', 'alpha3_code': 'ESP'},
          ],
          'total': 2,
        });
      });

      final countries = await repository.getCountries();

      expect(countries, hasLength(2));
      expect(countries.first.code, 'PT');
      expect(countries.last.name, 'Spain');
    });

    test('loads country visits', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/country-visits');

        return jsonResponse({
          'items': [
            {
              'id': 'e681d02a-b31a-4fd7-8f91-732da8742028',
              'country_code': 'PT',
              'started_on': '2025-07-10',
              'ended_on': '2025-07-15',
              'created_at': '2026-10-21T10:00:00',
              'updated_at': '2026-10-21T10:00:00',
            },
          ],
          'total': 1,
        });
      });

      final visits = await repository.getCountryVisits();

      expect(visits, hasLength(1));
      expect(visits.single.countryCode, 'PT');
      expect(visits.single.startedOn, DateTime(2025, 7, 10));
    });

    test('supports empty country lists', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      expect(await repository.getCountries(), isEmpty);
    });

    test('supports empty visit lists', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      expect(await repository.getCountryVisits(), isEmpty);
    });

    test('rejects malformed countries response', () async {
      final repository = createRepository((_) => jsonResponse({'total': 0}));

      await expectLater(repository.getCountries(), throwsFormatException);
    });

    test('rejects malformed visits response', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid'}),
      );

      await expectLater(repository.getCountryVisits(), throwsFormatException);
    });

    test('maps HTTP 401 to unauthorized', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getCountryVisits(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });

    test('maps HTTP 500 to server error', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Internal server error.'}, statusCode: 500),
      );

      await expectLater(
        repository.getCountries(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.server,
          ),
        ),
      );
    });
  });
  test('creates a country visit with exact dates', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/country-visits');

        final payload = options.data as Map<String, dynamic>;

        expect(payload, {
          'country_code': 'PT',
          'started_on': '2026-10-10',
          'ended_on': '2026-10-15',
        });

        expect(payload.containsKey('user_id'), isFalse);

        return ResponseBody.fromString(
          jsonEncode({
            'id': 'visit-1',
            'country_code': 'PT',
            'started_on': '2026-10-10',
            'ended_on': '2026-10-15',
            'created_at': '2026-10-21T06:00:00',
            'updated_at': '2026-10-21T06:00:00',
          }),
          201,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

    final repository = ApiCountriesRepository(
      apiClient: ApiClient(
        serverConfig: ServerConfig.parse('https://travel.example.com')!,
        dio: dio,
      ),
    );

    final visit = await repository.createCountryVisit(
      countryCode: ' pt ',
      startedOn: DateTime(2026, 10, 10),
      endedOn: DateTime(2026, 10, 15),
    );

    expect(visit.id, 'visit-1');
    expect(visit.countryCode, 'PT');
    expect(visit.startedOn, DateTime(2026, 10, 10));
    expect(visit.endedOn, DateTime(2026, 10, 15));
  });
  test('creates a country visit without dates', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((options) {
        expect(options.method, 'POST');

        expect(options.data, {
          'country_code': 'ES',
          'started_on': null,
          'ended_on': null,
        });

        return ResponseBody.fromString(
          jsonEncode({
            'id': 'visit-2',
            'country_code': 'ES',
            'started_on': null,
            'ended_on': null,
            'created_at': '2026-10-21T06:00:00',
            'updated_at': '2026-10-21T06:00:00',
          }),
          201,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

    final repository = ApiCountriesRepository(
      apiClient: ApiClient(
        serverConfig: ServerConfig.parse('https://travel.example.com')!,
        dio: dio,
      ),
    );

    final visit = await repository.createCountryVisit(countryCode: 'es');

    expect(visit.countryCode, 'ES');
    expect(visit.startedOn, isNull);
    expect(visit.endedOn, isNull);
  });
  test('maps validation errors when creating a visit', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'detail': 'End date cannot be earlier than start date.'}),
          422,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

    final repository = ApiCountriesRepository(
      apiClient: ApiClient(
        serverConfig: ServerConfig.parse('https://travel.example.com')!,
        dio: dio,
      ),
    );

    await expectLater(
      repository.createCountryVisit(
        countryCode: 'PT',
        startedOn: DateTime(2026, 10, 15),
        endedOn: DateTime(2026, 10, 10),
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
