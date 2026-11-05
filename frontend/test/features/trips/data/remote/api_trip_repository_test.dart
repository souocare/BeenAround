import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/trips/data/remote/api_trip_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';

const japanTripId = '550e8400-e29b-41d4-a716-446655440101';
const italyTripId = '550e8400-e29b-41d4-a716-446655440102';

/// Fake HTTP adapter following the existing project testing conventions.
class FakeTripHttpAdapter implements HttpClientAdapter {
  FakeTripHttpAdapter(this.handler);

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

Map<String, dynamic> tripResponse({
  String id = japanTripId,
  String name = 'Japan 2027',
  String? description = 'Spring holiday',
  String? startedOn = '2027-04-10',
  String? startedOnPrecision = 'day',
  String? endedOn = '2027-04-25',
  String? endedOnPrecision = 'day',
}) {
  return {
    'id': id,
    'name': name,
    'description': description,
    'started_on': startedOn,
    'started_on_precision': startedOnPrecision,
    'ended_on': endedOn,
    'ended_on_precision': endedOnPrecision,
    'created_at': '2026-11-05T10:00:00Z',
    'updated_at': '2026-11-05T10:00:00Z',
  };
}

ApiTripRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()..httpClientAdapter = FakeTripHttpAdapter(handler);

  return ApiTripRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiTripRepository - listing', () {
    test('loads Trips from the authenticated API', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/trips');

        return jsonResponse({
          'items': [
            tripResponse(),
            tripResponse(
              id: italyTripId,
              name: 'Italy 2026',
              description: null,
              startedOn: null,
              startedOnPrecision: null,
              endedOn: null,
              endedOnPrecision: null,
            ),
          ],
          'total': 2,
        });
      });

      final trips = await repository.getTrips();

      expect(trips, hasLength(2));

      final japan = trips.first;

      expect(japan.id, japanTripId);
      expect(japan.name, 'Japan 2027');
      expect(japan.description, 'Spring holiday');

      expect(japan.startedOn?.date, DateTime(2027, 4, 10));
      expect(japan.startedOn?.precision, VisitDatePrecision.day);

      expect(japan.endedOn?.date, DateTime(2027, 4, 25));
      expect(japan.endedOn?.precision, VisitDatePrecision.day);

      final italy = trips.last;

      expect(italy.id, italyTripId);
      expect(italy.name, 'Italy 2026');
      expect(italy.description, isNull);
      expect(italy.startedOn, isNull);
      expect(italy.endedOn, isNull);
    });

    test('supports an empty Trips list', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      final trips = await repository.getTrips();

      expect(trips, isEmpty);
    });

    test('returns an immutable list', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [tripResponse()],
          'total': 1,
        }),
      );

      final trips = await repository.getTrips();

      expect(() => trips.clear(), throwsUnsupportedError);
    });

    test('preserves API ordering', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            tripResponse(id: italyTripId, name: 'Italy'),
            tripResponse(id: japanTripId, name: 'Japan'),
          ],
          'total': 2,
        }),
      );

      final trips = await repository.getTrips();

      expect(trips.map((trip) => trip.name).toList(), ['Italy', 'Japan']);
    });

    test('parses partial dates correctly', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            tripResponse(
              startedOn: '2027-04-01',
              startedOnPrecision: 'month',
              endedOn: '2028-01-01',
              endedOnPrecision: 'year',
            ),
          ],
          'total': 1,
        }),
      );

      final trips = await repository.getTrips();

      final trip = trips.single;

      expect(trip.startedOn?.date, DateTime(2027, 4, 1));
      expect(trip.startedOn?.precision, VisitDatePrecision.month);

      expect(trip.endedOn?.date, DateTime(2028, 1, 1));
      expect(trip.endedOn?.precision, VisitDatePrecision.year);
    });

    test('supports Trips with only a start date', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [tripResponse(endedOn: null, endedOnPrecision: null)],
          'total': 1,
        }),
      );

      final trip = (await repository.getTrips()).single;

      expect(trip.startedOn, isNotNull);
      expect(trip.endedOn, isNull);
    });

    test('supports Trips with only an end date', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [tripResponse(startedOn: null, startedOnPrecision: null)],
          'total': 1,
        }),
      );

      final trip = (await repository.getTrips()).single;

      expect(trip.startedOn, isNull);
      expect(trip.endedOn, isNotNull);
    });

    test('rejects response without items', () async {
      final repository = createRepository((_) => jsonResponse({'total': 0}));

      await expectLater(repository.getTrips(), throwsFormatException);
    });

    test('rejects malformed items', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid', 'total': 0}),
      );

      await expectLater(repository.getTrips(), throwsFormatException);
    });

    test('rejects invalid date precision', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [tripResponse(startedOnPrecision: 'week')],
          'total': 1,
        }),
      );

      await expectLater(repository.getTrips(), throwsFormatException);
    });

    test('rejects a date without precision', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [tripResponse(startedOnPrecision: null)],
          'total': 1,
        }),
      );

      await expectLater(repository.getTrips(), throwsFormatException);
    });

    test('rejects a non-canonical month date', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            tripResponse(startedOn: '2027-04-15', startedOnPrecision: 'month'),
          ],
          'total': 1,
        }),
      );

      await expectLater(repository.getTrips(), throwsFormatException);
    });

    test('maps HTTP 401 to unauthorized', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getTrips(),
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
        repository.getTrips(),
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

  group('ApiTripRepository - details', () {
    test('retrieves a single Trip', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/trips/$japanTripId');

        return jsonResponse(tripResponse());
      });

      final trip = await repository.getTrip(tripId: japanTripId);

      expect(trip.id, japanTripId);
      expect(trip.name, 'Japan 2027');
      expect(trip.description, 'Spring holiday');
    });

    test('parses a Trip without dates', () async {
      final repository = createRepository(
        (_) => jsonResponse(
          tripResponse(
            startedOn: null,
            startedOnPrecision: null,
            endedOn: null,
            endedOnPrecision: null,
          ),
        ),
      );

      final trip = await repository.getTrip(tripId: japanTripId);

      expect(trip.startedOn, isNull);
      expect(trip.endedOn, isNull);
      expect(trip.hasDates, isFalse);
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Trip not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.getTrip(tripId: japanTripId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });

    test('rejects an empty Trip ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(tripResponse());
      });

      await expectLater(repository.getTrip(tripId: '   '), throwsArgumentError);

      expect(requestCount, 0);
    });

    test('trims whitespace from Trip IDs', () async {
      final repository = createRepository((options) {
        expect(options.uri.path, '/api/v1/trips/$japanTripId');

        return jsonResponse(tripResponse());
      });

      final trip = await repository.getTrip(tripId: '  $japanTripId  ');

      expect(trip.id, japanTripId);
    });

    test('rejects malformed Trip details', () async {
      final repository = createRepository(
        (_) => jsonResponse(tripResponse(endedOn: 'invalid-date')),
      );

      await expectLater(
        repository.getTrip(tripId: japanTripId),
        throwsFormatException,
      );
    });
  });
  group('ApiTripRepository - creation', () {
    test('creates a Trip without dates', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/trips');

        expect(options.data, {
          'name': 'Japan 2027',
          'description': null,
          'started_on': null,
          'started_on_precision': null,
          'ended_on': null,
          'ended_on_precision': null,
        });

        return jsonResponse(
          tripResponse(
            startedOn: null,
            startedOnPrecision: null,
            endedOn: null,
            endedOnPrecision: null,
          ),
          statusCode: 201,
        );
      });

      final trip = await repository.createTrip(
        input: const TripInput(name: 'Japan 2027'),
      );

      expect(trip.id, japanTripId);
      expect(trip.name, 'Japan 2027');
      expect(trip.startedOn, isNull);
      expect(trip.endedOn, isNull);
    });

    test('rejects invalid input before sending HTTP request', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(tripResponse(), statusCode: 201);
      });

      await expectLater(
        repository.createTrip(input: const TripInput(name: '   ')),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('maps HTTP 422 to validation error', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Invalid Trip dates.'}, statusCode: 422),
      );

      await expectLater(
        repository.createTrip(input: const TripInput(name: 'Japan')),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.validation,
          ),
        ),
      );
    });
  });
  group('ApiTripRepository - updates', () {
    test('updates an existing Trip', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');
        expect(options.uri.path, '/api/v1/trips/$japanTripId');

        expect(options.data, {
          'name': 'Japan & Korea 2027',
          'description': 'Updated description',
          'started_on': null,
          'started_on_precision': null,
          'ended_on': null,
          'ended_on_precision': null,
        });

        return jsonResponse(
          tripResponse(
            name: 'Japan & Korea 2027',
            description: 'Updated description',
            startedOn: null,
            startedOnPrecision: null,
            endedOn: null,
            endedOnPrecision: null,
          ),
        );
      });

      final trip = await repository.updateTrip(
        tripId: japanTripId,
        input: const TripInput(
          name: 'Japan & Korea 2027',
          description: 'Updated description',
        ),
      );

      expect(trip.name, 'Japan & Korea 2027');
      expect(trip.description, 'Updated description');
    });

    test('clears dates using explicit null', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.data['started_on'], isNull);
        expect(options.data['started_on_precision'], isNull);

        expect(options.data['ended_on'], isNull);
        expect(options.data['ended_on_precision'], isNull);

        return jsonResponse(
          tripResponse(
            startedOn: null,
            startedOnPrecision: null,
            endedOn: null,
            endedOnPrecision: null,
          ),
        );
      });

      final trip = await repository.updateTrip(
        tripId: japanTripId,
        input: const TripInput(name: 'Japan'),
      );

      expect(trip.startedOn, isNull);
      expect(trip.endedOn, isNull);
    });

    test('rejects an empty Trip ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(tripResponse());
      });

      await expectLater(
        repository.updateTrip(
          tripId: '   ',
          input: const TripInput(name: 'Japan'),
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Trip not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.updateTrip(
          tripId: japanTripId,
          input: const TripInput(name: 'Japan'),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
  group('ApiTripRepository - deletion', () {
    test('deletes a Trip with HTTP 204', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');
        expect(options.uri.path, '/api/v1/trips/$japanTripId');

        return ResponseBody.fromString('', 204);
      });

      await repository.deleteTrip(tripId: japanTripId);
    });

    test('rejects an empty Trip ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return ResponseBody.fromString('', 204);
      });

      await expectLater(repository.deleteTrip(tripId: ''), throwsArgumentError);

      expect(requestCount, 0);
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Trip not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.deleteTrip(tripId: japanTripId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
}
