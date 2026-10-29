import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
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
            {
              'code': 'PT',
              'name': 'Portugal',
              'alpha3_code': 'PRT',
              'continent': 'Europe',
            },
            {
              'code': 'ES',
              'name': 'Spain',
              'alpha3_code': 'ESP',
              'continent': 'Europe',
            },
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
          'started_on_precision': 'day',
          'ended_on': '2026-10-15',
          'ended_on_precision': 'day',
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

  test('creates a country visit with month precision', () async {
    final repository = createRepository((options) {
      expect(options.method, 'POST');
      expect(options.uri.path, '/api/v1/country-visits');

      expect(options.data, {
        'country_code': 'PT',
        'started_on': '2026-10-01',
        'started_on_precision': 'month',
        'ended_on': '2026-12-01',
        'ended_on_precision': 'month',
      });

      return jsonResponse({
        'id': 'visit-1',
        'country_code': 'PT',
        'started_on': '2026-10-01',
        'started_on_precision': 'month',
        'ended_on': null,
        'ended_on_precision': null,
        'created_at': '2026-10-21T10:00:00',
        'updated_at': '2026-10-21T10:00:00',
      }, statusCode: 201);
    });

    final visit = await repository.createCountryVisit(
      countryCode: 'PT',
      startedOn: DateTime(2026, 10, 1),
      endedOn: DateTime(2026, 12, 1),
      startedOnPrecision: VisitDatePrecision.month,
      endedOnPrecision: VisitDatePrecision.month,
    );

    expect(visit.startedOn, DateTime(2026, 10, 1));
    expect(visit.startedOnPrecision, VisitDatePrecision.month);
    expect(visit.endedOn, isNull);
  });
  test('creates a country visit with year precision', () async {
    final repository = createRepository((options) {
      expect(options.method, 'POST');

      expect(options.data, {
        'country_code': 'PT',
        'started_on': '2024-01-01',
        'started_on_precision': 'year',
        'ended_on': '2025-01-01',
        'ended_on_precision': 'year',
      });

      return jsonResponse({
        'id': 'visit-1',
        'country_code': 'PT',
        'started_on': '2024-01-01',
        'started_on_precision': 'year',
        'ended_on': null,
        'ended_on_precision': null,
        'created_at': '2026-10-21T10:00:00',
        'updated_at': '2026-10-21T10:00:00',
      }, statusCode: 201);
    });

    final visit = await repository.createCountryVisit(
      countryCode: 'PT',
      startedOn: DateTime(2024, 1, 1),
      endedOn: DateTime(2025, 1, 1),
      startedOnPrecision: VisitDatePrecision.year,
      endedOnPrecision: VisitDatePrecision.year,
    );

    expect(visit.startedOn, DateTime(2024, 1, 1));
    expect(visit.startedOnPrecision, VisitDatePrecision.year);
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
  test('updates a country visit with exact dates', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');
      expect(options.uri.path, '/api/v1/country-visits/visit-1');

      expect(options.data, {
        'started_on': '2026-10-10',
        'ended_on': '2026-10-15',
      });

      expect((options.data as Map).containsKey('country_code'), isFalse);
      expect((options.data as Map).containsKey('user_id'), isFalse);

      return jsonResponse({
        'id': 'visit-1',
        'country_code': 'PT',
        'started_on': '2026-10-10',
        'ended_on': '2026-10-15',
        'created_at': '2026-10-20T10:00:00',
        'updated_at': '2026-10-21T10:00:00',
      });
    });

    final visit = await repository.updateCountryVisit(
      visitId: 'visit-1',
      changes: {
        'started_on': DateTime(2026, 10, 10),
        'ended_on': DateTime(2026, 10, 15),
      },
    );

    expect(visit.id, 'visit-1');
    expect(visit.countryCode, 'PT');
    expect(visit.startedOn, DateTime(2026, 10, 10));
    expect(visit.endedOn, DateTime(2026, 10, 15));
  });
  test('rejects clearing visit dates without an HTTP request', () async {
    var requestCount = 0;

    final repository = createRepository((_) {
      requestCount++;
      fail('No HTTP request should be sent.');
    });

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {'ended_on': null},
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {'started_on': null, 'ended_on': null},
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {'started_on_precision': null},
      ),
      throwsArgumentError,
    );

    expect(requestCount, 0);
  });
  test('maps validation errors when updating a visit', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');

      return jsonResponse({
        'detail': 'End date cannot be earlier than start date.',
      }, statusCode: 422);
    });

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {
          'started_on': DateTime(2026, 10, 15),
          'ended_on': DateTime(2026, 10, 10),
        },
      ),
      throwsA(isA<ApiException>()),
    );
  });
  test('maps not found errors when updating a visit', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');

      return jsonResponse({
        'detail': 'Country visit not found.',
      }, statusCode: 404);
    });

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {'started_on': DateTime(2026, 10, 10)},
      ),
      throwsA(isA<ApiException>()),
    );
  });
  test('rejects an empty update response', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');

      return ResponseBody.fromString(
        '',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    await expectLater(
      repository.updateCountryVisit(
        visitId: 'visit-1',
        changes: {'started_on': DateTime(2026, 10, 10)},
      ),
      throwsA(isA<FormatException>()),
    );
  });
  test('deletes a country visit', () async {
    final repository = createRepository((options) {
      expect(options.method, 'DELETE');
      expect(options.uri.path, '/api/v1/country-visits/visit-1');

      return ResponseBody.fromString('', 204);
    });

    await repository.deleteCountryVisit(visitId: 'visit-1');
  });
  test('maps not found errors when deleting a visit', () async {
    final repository = createRepository((options) {
      expect(options.method, 'DELETE');

      return jsonResponse({
        'detail': 'Country visit not found.',
      }, statusCode: 404);
    });

    await expectLater(
      repository.deleteCountryVisit(visitId: 'visit-1'),
      throwsA(isA<ApiException>()),
    );
  });
  test('maps server errors when deleting a visit', () async {
    final repository = createRepository((options) {
      expect(options.method, 'DELETE');

      return jsonResponse({
        'detail': 'Internal server error.',
      }, statusCode: 500);
    });

    await expectLater(
      repository.deleteCountryVisit(visitId: 'visit-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiErrorType.server,
        ),
      ),
    );
  });
  test('updates only the provided start date', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');

      expect(options.data, {'started_on': '2026-10-10'});

      return jsonResponse({
        'id': 'visit-1',
        'country_code': 'PT',
        'started_on': '2026-10-10',
        'ended_on': '2026-10-15',
        'created_at': '2026-10-20T10:00:00',
        'updated_at': '2026-10-21T10:00:00',
      });
    });

    final visit = await repository.updateCountryVisit(
      visitId: 'visit-1',
      changes: {'started_on': DateTime(2026, 10, 10)},
    );

    expect(visit.startedOn, DateTime(2026, 10, 10));
    expect(visit.endedOn, DateTime(2026, 10, 15));
  });
  test('updates only the start date precision', () async {
    final repository = createRepository((options) {
      expect(options.method, 'PATCH');

      expect(options.data, {'started_on_precision': 'month'});

      return jsonResponse({
        'id': 'visit-1',
        'country_code': 'PT',
        'started_on': '2026-10-01',
        'started_on_precision': 'month',
        'ended_on': '2026-10-15',
        'ended_on_precision': 'day',
        'created_at': '2026-10-20T10:00:00',
        'updated_at': '2026-10-21T10:00:00',
      });
    });

    final visit = await repository.updateCountryVisit(
      visitId: 'visit-1',
      changes: {'started_on_precision': VisitDatePrecision.month},
    );

    expect(visit.startedOn, DateTime(2026, 10, 1));
    expect(visit.startedOnPrecision, VisitDatePrecision.month);
  });
  test('rejects an empty country visit update', () async {
    final repository = createRepository((options) {
      fail('No HTTP request should be sent for an empty update.');
    });

    await expectLater(
      repository.updateCountryVisit(visitId: 'visit-1', changes: {}),
      throwsA(isA<ArgumentError>()),
    );
  });
}
