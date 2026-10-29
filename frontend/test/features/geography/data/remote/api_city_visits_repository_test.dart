import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/geography/data/remote/api_city_visits_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsHttpAdapter implements HttpClientAdapter {
  FakeCityVisitsHttpAdapter(this.handler);

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

const visitId = 'e681d02a-b31a-4fd7-8f91-732da8742028';
const secondVisitId = '550e8400-e29b-41d4-a716-446655440000';

Map<String, dynamic> visitResponse({
  String id = visitId,
  int cityId = 2267057,
  String cityName = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
  String startedOn = '2025-07-10',
  String endedOn = '2025-07-15',
  String startedOnPrecision = 'day',
  String endedOnPrecision = 'day',
}) {
  return {
    'id': id,
    'city_id': cityId,
    'city_name': cityName,
    'country_code': countryCode,
    'country_name': countryName,
    'started_on': startedOn,
    'ended_on': endedOn,
    'started_on_precision': startedOnPrecision,
    'ended_on_precision': endedOnPrecision,
    'created_at': '2026-10-21T10:00:00',
    'updated_at': '2026-10-21T10:00:00',
  };
}

ApiCityVisitsRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()..httpClientAdapter = FakeCityVisitsHttpAdapter(handler);

  return ApiCityVisitsRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiCityVisitsRepository - listing', () {
    test('loads visits from the configured API', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/city-visits');

        return jsonResponse({
          'items': [
            visitResponse(),
            visitResponse(
              id: secondVisitId,
              startedOn: '2026-02-01',
              endedOn: '2026-02-05',
            ),
          ],
          'total': 2,
        });
      });

      final visits = await repository.getCityVisits();

      expect(visits, hasLength(2));
      expect(visits.first.cityId, 2267057);
      expect(visits.last.cityId, 2267057);
      expect(visits.first.id, isNot(visits.last.id));
      expect(visits.first.cityName, 'Lisbon');
      expect(visits.first.countryCode, 'PT');
      expect(visits.first.startedOn, DateTime(2025, 7, 10));
      expect(visits.last.startedOn, DateTime(2026, 2, 1));
    });

    test('supports an empty visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      expect(await repository.getCityVisits(), isEmpty);
    });

    test('rejects missing items', () async {
      final repository = createRepository((_) => jsonResponse({'total': 0}));

      await expectLater(repository.getCityVisits(), throwsFormatException);
    });

    test('rejects malformed items', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid'}),
      );

      await expectLater(repository.getCityVisits(), throwsFormatException);
    });

    test('rejects a missing response body', () async {
      final repository = createRepository(
        (_) => ResponseBody.fromString(
          '',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await expectLater(repository.getCityVisits(), throwsFormatException);
    });

    test('maps unauthorized responses', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getCityVisits(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });

    test('maps server errors', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Internal server error.'}, statusCode: 500),
      );

      await expectLater(
        repository.getCityVisits(),
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

  group('ApiCityVisitsRepository - creation', () {
    test('creates a visit with exact dates', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/city-visits');

        expect(options.data, {
          'city_id': 2267057,
          'started_on': '2026-10-10',
          'started_on_precision': 'day',
          'ended_on': '2026-10-15',
          'ended_on_precision': 'day',
        });

        expect((options.data as Map).containsKey('user_id'), isFalse);

        return jsonResponse(
          visitResponse(startedOn: '2026-10-10', endedOn: '2026-10-15'),
          statusCode: 201,
        );
      });

      final visit = await repository.createCityVisit(
        cityId: 2267057,
        startedOn: DateTime(2026, 10, 10, 14, 30),
        endedOn: DateTime(2026, 10, 15, 18),
      );

      expect(visit.id, visitId);
      expect(visit.cityId, 2267057);
      expect(visit.startedOn, DateTime(2026, 10, 10));
      expect(visit.endedOn, DateTime(2026, 10, 15));
    });

    test('maps invalid city IDs returned by the API', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'City not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.createCityVisit(
          cityId: 999999999,
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps validation errors', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'End date cannot be earlier than start date.',
        }, statusCode: 422),
      );

      await expectLater(
        repository.createCityVisit(
          cityId: 2267057,
          startedOn: DateTime(2026, 10, 15),
          endedOn: DateTime(2026, 10, 10),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects a missing creation response', () async {
      final repository = createRepository(
        (_) => ResponseBody.fromString(
          '',
          201,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await expectLater(
        repository.createCityVisit(
          cityId: 2267057,
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
        throwsFormatException,
      );
    });
    test('creates a city visit with month precision', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/city-visits');

        expect(options.data, {
          'city_id': 2267057,
          'started_on': '2026-10-01',
          'started_on_precision': 'month',
          'ended_on': '2026-12-01',
          'ended_on_precision': 'month',
        });

        return jsonResponse(
          visitResponse(
            startedOn: '2026-10-01',
            endedOn: '2026-12-01',
            startedOnPrecision: 'month',
            endedOnPrecision: 'month',
          ),
          statusCode: 201,
        );
      });

      final visit = await repository.createCityVisit(
        cityId: 2267057,
        startedOn: DateTime(2026, 10, 1),
        endedOn: DateTime(2026, 12, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(visit.startedOn, DateTime(2026, 10, 1));
      expect(visit.startedOnPrecision, VisitDatePrecision.month);
      expect(visit.endedOn, DateTime(2026, 12, 1));
      expect(visit.endedOnPrecision, VisitDatePrecision.month);
    });
    test('creates a city visit with year precision', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');

        expect(options.data, {
          'city_id': 2267057,
          'started_on': '2024-01-01',
          'started_on_precision': 'year',
          'ended_on': '2025-01-01',
          'ended_on_precision': 'year',
        });

        return jsonResponse(
          visitResponse(
            startedOn: '2024-01-01',
            endedOn: '2025-01-01',
            startedOnPrecision: 'year',
            endedOnPrecision: 'year',
          ),
          statusCode: 201,
        );
      });

      final visit = await repository.createCityVisit(
        cityId: 2267057,
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2025, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.year,
      );

      expect(visit.startedOn, DateTime(2024, 1, 1));
      expect(visit.startedOnPrecision, VisitDatePrecision.year);
    });
  });

  group('ApiCityVisitsRepository - updates', () {
    test('updates only the city ID', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');
        expect(options.uri.path, '/api/v1/city-visits/$visitId');

        expect(options.data, {'city_id': 3117735});

        return jsonResponse(
          visitResponse(
            cityId: 3117735,
            cityName: 'Madrid',
            countryCode: 'ES',
            countryName: 'Spain',
          ),
        );
      });

      final visit = await repository.updateCityVisit(
        visitId: visitId,
        changes: {'city_id': 3117735},
      );

      expect(visit.cityId, 3117735);
      expect(visit.cityName, 'Madrid');
      expect(visit.countryCode, 'ES');
      expect(visit.startedOn, DateTime(2025, 7, 10));
    });

    test('updates only the start date', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.data, {'started_on': '2025-07-12'});

        return jsonResponse(visitResponse(startedOn: '2025-07-12'));
      });

      final visit = await repository.updateCityVisit(
        visitId: visitId,
        changes: {'started_on': DateTime(2025, 7, 12)},
      );

      expect(visit.startedOn, DateTime(2025, 7, 12));
      expect(visit.endedOn, DateTime(2025, 7, 15));
    });

    test('rejects clearing visit dates without an HTTP request', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;
        fail('No HTTP request should be sent.');
      });

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'ended_on': null},
        ),
        throwsArgumentError,
      );

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'started_on': null, 'ended_on': null},
        ),
        throwsArgumentError,
      );

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'ended_on_precision': null},
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects empty changes before sending a request', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;
        return jsonResponse(visitResponse());
      });

      await expectLater(
        repository.updateCityVisit(visitId: visitId, changes: {}),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects unsupported fields', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;
        return jsonResponse(visitResponse());
      });

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'user_id': 'another-user'},
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects null city ID', () async {
      final repository = createRepository((_) => jsonResponse(visitResponse()));

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'city_id': null},
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive city IDs', () async {
      final repository = createRepository((_) => jsonResponse(visitResponse()));

      await expectLater(
        repository.updateCityVisit(visitId: visitId, changes: {'city_id': 0}),
        throwsArgumentError,
      );
    });

    test('rejects invalid date types', () async {
      final repository = createRepository((_) => jsonResponse(visitResponse()));

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'started_on': '2026-10-10'},
        ),
        throwsArgumentError,
      );
    });

    test('maps validation errors', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'End date cannot be earlier than start date.',
        }, statusCode: 422),
      );

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {
            'started_on': DateTime(2026, 10, 15),
            'ended_on': DateTime(2026, 10, 10),
          },
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps missing visits', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'City visit not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'city_id': 2267057},
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects missing update responses', () async {
      final repository = createRepository(
        (_) => ResponseBody.fromString(
          '',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await expectLater(
        repository.updateCityVisit(
          visitId: visitId,
          changes: {'city_id': 2267057},
        ),
        throwsFormatException,
      );
    });
  });

  group('ApiCityVisitsRepository - deletion', () {
    test('deletes a city visit', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');
        expect(options.uri.path, '/api/v1/city-visits/$visitId');

        return ResponseBody.fromString('', 204);
      });

      await repository.deleteCityVisit(visitId: visitId);
    });

    test('maps missing visits', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'City visit not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.deleteCityVisit(visitId: visitId),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps server errors', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Internal server error.'}, statusCode: 500),
      );

      await expectLater(
        repository.deleteCityVisit(visitId: visitId),
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
}
