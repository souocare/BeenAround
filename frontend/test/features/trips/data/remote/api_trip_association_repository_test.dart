import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/trips/data/remote/api_trip_association_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const tripId = '550e8400-e29b-41d4-a716-446655440101';
const countryVisitId = '550e8400-e29b-41d4-a716-446655440201';
const cityVisitId = '550e8400-e29b-41d4-a716-446655440301';

class FakeTripAssociationHttpAdapter implements HttpClientAdapter {
  FakeTripAssociationHttpAdapter(this.handler);

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

Map<String, dynamic> countryVisitResponse({
  String id = countryVisitId,
  String countryCode = 'JP',
}) {
  return {
    'id': id,
    'country_code': countryCode,
    'started_on': '2027-04-01',
    'started_on_precision': 'month',
    'ended_on': '2027-04-25',
    'ended_on_precision': 'day',
    'created_at': '2026-11-05T10:00:00Z',
    'updated_at': '2026-11-05T10:00:00Z',
  };
}

Map<String, dynamic> cityVisitResponse({String id = cityVisitId}) {
  return {
    'id': id,
    'city_id': 1850147,
    'city_name': 'Tokyo',
    'country_code': 'JP',
    'country_name': 'Japan',
    'country_visit_id': countryVisitId,
    'started_on': '2027-04-10',
    'started_on_precision': 'day',
    'ended_on': '2027-04-15',
    'ended_on_precision': 'day',
    'created_at': '2026-11-05T10:00:00Z',
    'updated_at': '2026-11-05T10:00:00Z',
  };
}

ApiTripAssociationRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()
    ..httpClientAdapter = FakeTripAssociationHttpAdapter(handler);

  return ApiTripAssociationRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiTripAssociationRepository - country visits', () {
    test('loads associated country visits', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/trips/$tripId/country-visits');

        return jsonResponse({
          'items': [countryVisitResponse()],
          'total': 1,
        });
      });

      final visits = await repository.getCountryVisits(tripId: tripId);

      expect(visits, hasLength(1));

      final visit = visits.single;

      expect(visit.id, countryVisitId);
      expect(visit.countryCode, 'JP');

      expect(visit.startedOn, DateTime(2027, 4, 1));

      expect(visit.startedOnPrecision, VisitDatePrecision.month);

      expect(visit.endedOn, DateTime(2027, 4, 25));

      expect(visit.endedOnPrecision, VisitDatePrecision.day);
    });

    test('supports an empty country visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      final visits = await repository.getCountryVisits(tripId: tripId);

      expect(visits, isEmpty);
    });

    test('returns an immutable country visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [countryVisitResponse()],
          'total': 1,
        }),
      );

      final visits = await repository.getCountryVisits(tripId: tripId);

      expect(() => visits.clear(), throwsUnsupportedError);
    });

    test('preserves API ordering', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            countryVisitResponse(countryCode: 'JP'),
            countryVisitResponse(
              id: '550e8400-e29b-41d4-a716-446655440202',
              countryCode: 'KR',
            ),
          ],
          'total': 2,
        }),
      );

      final visits = await repository.getCountryVisits(tripId: tripId);

      expect(visits.map((visit) => visit.countryCode).toList(), ['JP', 'KR']);
    });

    test('rejects a response without items', () async {
      final repository = createRepository((_) => jsonResponse({'total': 0}));

      await expectLater(
        repository.getCountryVisits(tripId: tripId),
        throwsFormatException,
      );
    });

    test('rejects malformed items', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid', 'total': 0}),
      );

      await expectLater(
        repository.getCountryVisits(tripId: tripId),
        throwsFormatException,
      );
    });

    test('rejects missing response body', () async {
      final repository = createRepository(
        (_) => ResponseBody.fromString('', 204),
      );

      await expectLater(
        repository.getCountryVisits(tripId: tripId),
        throwsFormatException,
      );
    });

    test('adds a country visit using the correct payload', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');

        expect(options.uri.path, '/api/v1/trips/$tripId/country-visits');

        expect(options.data, {'country_visit_id': countryVisitId});

        return jsonResponse({
          'trip_id': tripId,
          'visit_id': countryVisitId,
        }, statusCode: 201);
      });

      await repository.addCountryVisit(tripId: tripId, visitId: countryVisitId);
    });

    test('accepts an already existing association', () async {
      final repository = createRepository(
        (_) => jsonResponse({'trip_id': tripId, 'visit_id': countryVisitId}),
      );

      await repository.addCountryVisit(tripId: tripId, visitId: countryVisitId);
    });

    test('removes an association without deleting the visit', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');

        expect(
          options.uri.path,
          '/api/v1/trips/$tripId/country-visits/$countryVisitId',
        );

        return ResponseBody.fromString('', 204);
      });

      await repository.removeCountryVisit(
        tripId: tripId,
        visitId: countryVisitId,
      );
    });
  });

  group('ApiTripAssociationRepository - city visits', () {
    test('loads associated city visits with catalog details', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');

        expect(options.uri.path, '/api/v1/trips/$tripId/city-visits');

        return jsonResponse({
          'items': [cityVisitResponse()],
          'total': 1,
        });
      });

      final visits = await repository.getCityVisits(tripId: tripId);

      expect(visits, hasLength(1));

      final visit = visits.single;

      expect(visit.id, cityVisitId);
      expect(visit.cityId, 1850147);
      expect(visit.cityName, 'Tokyo');
      expect(visit.countryCode, 'JP');
      expect(visit.countryName, 'Japan');

      expect(visit.countryVisitId, countryVisitId);

      expect(visit.startedOn, DateTime(2027, 4, 10));

      expect(visit.startedOnPrecision, VisitDatePrecision.day);
    });

    test('supports an empty city visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      final visits = await repository.getCityVisits(tripId: tripId);

      expect(visits, isEmpty);
    });

    test('returns an immutable city visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [cityVisitResponse()],
          'total': 1,
        }),
      );

      final visits = await repository.getCityVisits(tripId: tripId);

      expect(() => visits.clear(), throwsUnsupportedError);
    });

    test('rejects malformed city visit list', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': null, 'total': 0}),
      );

      await expectLater(
        repository.getCityVisits(tripId: tripId),
        throwsFormatException,
      );
    });

    test('adds a city visit using the correct payload', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');

        expect(options.uri.path, '/api/v1/trips/$tripId/city-visits');

        expect(options.data, {'city_visit_id': cityVisitId});

        return jsonResponse({
          'trip_id': tripId,
          'visit_id': cityVisitId,
        }, statusCode: 201);
      });

      await repository.addCityVisit(tripId: tripId, visitId: cityVisitId);
    });

    test('accepts an already associated city visit', () async {
      final repository = createRepository(
        (_) => jsonResponse({'trip_id': tripId, 'visit_id': cityVisitId}),
      );

      await repository.addCityVisit(tripId: tripId, visitId: cityVisitId);
    });

    test('removes a city association with HTTP 204', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');

        expect(
          options.uri.path,
          '/api/v1/trips/$tripId/city-visits/$cityVisitId',
        );

        return ResponseBody.fromString('', 204);
      });

      await repository.removeCityVisit(tripId: tripId, visitId: cityVisitId);
    });
  });

  group('ApiTripAssociationRepository - validation', () {
    test('rejects an empty Trip ID before HTTP', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse({'items': [], 'total': 0});
      });

      await expectLater(
        repository.getCountryVisits(tripId: '   '),
        throwsArgumentError,
      );

      await expectLater(
        repository.getCityVisits(tripId: ''),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects an empty visit ID before HTTP', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse({});
      });

      await expectLater(
        repository.addCountryVisit(tripId: tripId, visitId: ''),
        throwsArgumentError,
      );

      await expectLater(
        repository.addCityVisit(tripId: tripId, visitId: '   '),
        throwsArgumentError,
      );

      await expectLater(
        repository.removeCountryVisit(tripId: tripId, visitId: ''),
        throwsArgumentError,
      );

      await expectLater(
        repository.removeCityVisit(tripId: tripId, visitId: '   '),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('normalizes whitespace in IDs', () async {
      final repository = createRepository((options) {
        expect(options.uri.path, '/api/v1/trips/$tripId/country-visits');

        expect(options.data, {'country_visit_id': countryVisitId});

        return jsonResponse({
          'trip_id': tripId,
          'visit_id': countryVisitId,
        }, statusCode: 201);
      });

      await repository.addCountryVisit(
        tripId: '  $tripId  ',
        visitId: '  $countryVisitId  ',
      );
    });
  });

  group('ApiTripAssociationRepository - HTTP errors', () {
    test('maps 401 to unauthorized', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getCountryVisits(tripId: tripId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });

    test('maps 404 to notFound', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Trip not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.addCityVisit(tripId: tripId, visitId: cityVisitId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });

    test('maps 422 to validation', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Invalid association.'}, statusCode: 422),
      );

      await expectLater(
        repository.addCountryVisit(tripId: tripId, visitId: countryVisitId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.validation,
          ),
        ),
      );
    });

    test('maps 500 to server error', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Internal server error.'}, statusCode: 500),
      );

      await expectLater(
        repository.removeCityVisit(tripId: tripId, visitId: cityVisitId),
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
