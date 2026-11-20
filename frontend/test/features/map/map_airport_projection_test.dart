import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/map/application/map_airport_projection.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  Flight flight({
    required String id,
    required int departure,
    required int arrival,
    FlightStatus status = FlightStatus.flown,
  }) {
    return Flight(
      id: id,
      departureAirportId: departure,
      arrivalAirportId: arrival,
      departureOn: '2026-01-01',
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  Airport airport({
    required int id,
    required String code,
    double? latitude = 38.7742,
    double? longitude = -9.1342,
  }) {
    return Airport(
      id: id,
      ident: code,
      iataCode: code,
      name: '$code Airport',
      type: 'large_airport',
      scheduledService: true,
      countryCode: 'PT',
      latitude: latitude,
      longitude: longitude,
    );
  }

  group('buildMapAirportProjection', () {
    test('returns an empty projection without flights', () {
      final result = buildMapAirportProjection(
        flights: const [],
        airports: const {},
      );

      expect(result, isEmpty);
    });

    test('aggregates arrivals and departures by airport', () {
      final flights = [
        flight(id: '1', departure: 1, arrival: 2),
        flight(id: '2', departure: 2, arrival: 1),
        flight(id: '3', departure: 1, arrival: 3),
      ];

      final result = buildMapAirportProjection(
        flights: flights,
        airports: {
          1: airport(id: 1, code: 'LIS'),
          2: airport(id: 2, code: 'LHR'),
          3: airport(id: 3, code: 'FNC'),
        },
      );

      expect(result, hasLength(3));

      expect(result[1]!.departureCount, 2);
      expect(result[1]!.arrivalCount, 1);
      expect(result[1]!.flightCount, 3);

      expect(result[2]!.departureCount, 1);
      expect(result[2]!.arrivalCount, 1);
      expect(result[2]!.flightCount, 2);

      expect(result[3]!.departureCount, 0);
      expect(result[3]!.arrivalCount, 1);
      expect(result[3]!.flightCount, 1);
    });

    test('excludes planned flights', () {
      final result = buildMapAirportProjection(
        flights: [
          flight(
            id: 'planned',
            departure: 1,
            arrival: 2,
            status: FlightStatus.planned,
          ),
        ],
        airports: {
          1: airport(id: 1, code: 'LIS'),
          2: airport(id: 2, code: 'FNC'),
        },
      );

      expect(result, isEmpty);
    });

    test('deduplicates the same flight ID', () {
      final recordedFlight = flight(
        id: 'same-flight',
        departure: 1,
        arrival: 2,
      );

      final result = buildMapAirportProjection(
        flights: [recordedFlight, recordedFlight],
        airports: {
          1: airport(id: 1, code: 'LIS'),
          2: airport(id: 2, code: 'FNC'),
        },
      );

      expect(result[1]!.flightCount, 1);
      expect(result[2]!.flightCount, 1);
    });

    test('counts a circular flight only once per airport', () {
      final result = buildMapAirportProjection(
        flights: [flight(id: 'circular', departure: 1, arrival: 1)],
        airports: {1: airport(id: 1, code: 'LIS')},
      );

      expect(result[1]!.departureCount, 1);
      expect(result[1]!.arrivalCount, 1);
      expect(result[1]!.flightCount, 1);
    });

    test('skips airports without valid coordinates', () {
      final result = buildMapAirportProjection(
        flights: [flight(id: '1', departure: 1, arrival: 2)],
        airports: {
          1: airport(id: 1, code: 'LIS', latitude: null),
          2: airport(id: 2, code: 'FNC'),
        },
      );

      expect(result.containsKey(1), isFalse);
      expect(result.containsKey(2), isTrue);
    });

    test('does not create geographic visits', () {
      final result = buildMapAirportProjection(
        flights: [flight(id: '1', departure: 1, arrival: 2)],
        airports: {
          1: airport(id: 1, code: 'LIS'),
          2: airport(id: 2, code: 'DXB'),
        },
      );

      // The projection contains only airport summaries.
      // No country or city visits are produced.
      expect(result.keys, containsAll([1, 2]));
      expect(result[2]!.code, 'DXB');
    });

    test('returns an unmodifiable projection', () {
      final result = buildMapAirportProjection(
        flights: [flight(id: '1', departure: 1, arrival: 2)],
        airports: {
          1: airport(id: 1, code: 'LIS'),
          2: airport(id: 2, code: 'FNC'),
        },
      );

      expect(() => result.clear(), throwsUnsupportedError);
    });
  });
}
