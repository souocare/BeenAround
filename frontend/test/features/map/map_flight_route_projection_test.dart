import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/map/application/map_flight_route_projection.dart';

void main() {
  Flight flight({
    required String id,
    required int departureAirportId,
    required int arrivalAirportId,
    FlightStatus status = FlightStatus.flown,
    String departureOn = '2026-01-15',
    String? flightNumber,
    String? airlineName,
  }) {
    return Flight(
      id: id,
      departureAirportId: departureAirportId,
      arrivalAirportId: arrivalAirportId,
      departureOn: departureOn,
      flightNumber: flightNumber,
      airlineName: airlineName,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('buildMapFlightRouteProjection', () {
    test('returns no routes when there are no flights', () {
      final routes = buildMapFlightRouteProjection(flights: const []);

      expect(routes, isEmpty);
    });

    test('creates one route for a completed flight', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
        ],
      );

      expect(routes, hasLength(1));

      final route = routes.single;

      expect(route.id, '10:20');
      expect(route.firstAirportId, 10);
      expect(route.secondAirportId, 20);
      expect(route.flightCount, 1);

      expect(route.flights.single.flightId, 'F1');
    });

    test('excludes planned flights', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(
            id: 'F1',
            departureAirportId: 10,
            arrivalAirportId: 20,
            status: FlightStatus.planned,
          ),
        ],
      );

      expect(routes, isEmpty);
    });

    test('aggregates repeated flights into one visual route', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
          flight(id: 'F2', departureAirportId: 10, arrivalAirportId: 20),
          flight(id: 'F3', departureAirportId: 10, arrivalAirportId: 20),
        ],
      );

      expect(routes, hasLength(1));
      expect(routes.single.id, '10:20');
      expect(routes.single.flightCount, 3);
    });

    test('aggregates opposite directions into one visual route', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
          flight(id: 'F2', departureAirportId: 20, arrivalAirportId: 10),
        ],
      );

      expect(routes, hasLength(1));

      final route = routes.single;

      expect(route.id, '10:20');
      expect(route.flightCount, 2);

      final forward = route.flights.singleWhere(
        (item) => item.flightId == 'F1',
      );

      final reverse = route.flights.singleWhere(
        (item) => item.flightId == 'F2',
      );

      expect(forward.departureAirportId, 10);
      expect(forward.arrivalAirportId, 20);

      expect(reverse.departureAirportId, 20);
      expect(reverse.arrivalAirportId, 10);
    });

    test('keeps different airport connections separate', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
          flight(id: 'F2', departureAirportId: 10, arrivalAirportId: 30),
        ],
      );

      expect(routes, hasLength(2));

      expect(routes.map((route) => route.id), ['10:20', '10:30']);
    });

    test('ignores duplicate flight IDs', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
        ],
      );

      expect(routes, hasLength(1));
      expect(routes.single.flightCount, 1);
    });

    test('ignores invalid airport identifiers', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 0, arrivalAirportId: 20),
          flight(id: 'F2', departureAirportId: 10, arrivalAirportId: -1),
        ],
      );

      expect(routes, isEmpty);
    });

    test('does not draw same-airport connections', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 10),
        ],
      );

      expect(routes, isEmpty);
    });

    test('normalizes airport order', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 90, arrivalAirportId: 15),
        ],
      );

      final route = routes.single;

      expect(route.firstAirportId, 15);
      expect(route.secondAirportId, 90);
      expect(route.id, '15:90');
    });

    test('produces deterministic results regardless of flight order', () {
      final flights = [
        flight(id: 'F3', departureAirportId: 30, arrivalAirportId: 10),
        flight(id: 'F1', departureAirportId: 20, arrivalAirportId: 10),
        flight(id: 'F2', departureAirportId: 10, arrivalAirportId: 20),
      ];

      final first = buildMapFlightRouteProjection(flights: flights);

      final second = buildMapFlightRouteProjection(flights: flights.reversed);

      expect(
        first.map((route) => route.id).toList(),
        second.map((route) => route.id).toList(),
      );

      expect(
        first.first.flights.map((flight) => flight.flightId).toList(),
        second.first.flights.map((flight) => flight.flightId).toList(),
      );
    });

    test('returns an immutable route collection', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(id: 'F1', departureAirportId: 10, arrivalAirportId: 20),
        ],
      );

      expect(() => routes.clear(), throwsUnsupportedError);

      expect(() => routes.single.flights.clear(), throwsUnsupportedError);
    });
    test('preserves flight metadata for contextual presentation', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(
            id: 'F1',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2025-09-08',
            flightNumber: 'TP1234',
            airlineName: 'TAP Air Portugal',
          ),
        ],
      );

      final projectedFlight = routes.single.flights.single;

      expect(projectedFlight.flightId, 'F1');
      expect(projectedFlight.departureAirportId, 10);
      expect(projectedFlight.arrivalAirportId, 20);

      expect(projectedFlight.departureOn, '2025-09-08');
      expect(projectedFlight.flightNumber, 'TP1234');
      expect(projectedFlight.airlineName, 'TAP Air Portugal');
    });
    test('orders route flights from newest to oldest', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(
            id: 'F1',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2024-04-12',
          ),
          flight(
            id: 'F2',
            departureAirportId: 20,
            arrivalAirportId: 10,
            departureOn: '2024-04-19',
          ),
          flight(
            id: 'F3',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2025-09-08',
          ),
        ],
      );

      expect(routes.single.flights.map((flight) => flight.flightId).toList(), [
        'F3',
        'F2',
        'F1',
      ]);

      expect(
        routes.single.flights.map((flight) => flight.departureOn).toList(),
        ['2025-09-08', '2024-04-19', '2024-04-12'],
      );
    });
    test('uses flight ID as a stable tie-breaker for equal dates', () {
      final routes = buildMapFlightRouteProjection(
        flights: [
          flight(
            id: 'F3',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2025-05-10',
          ),
          flight(
            id: 'F1',
            departureAirportId: 20,
            arrivalAirportId: 10,
            departureOn: '2025-05-10',
          ),
          flight(
            id: 'F2',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2025-05-10',
          ),
        ],
      );

      expect(routes.single.flights.map((flight) => flight.flightId).toList(), [
        'F1',
        'F2',
        'F3',
      ]);
    });
  });
}
