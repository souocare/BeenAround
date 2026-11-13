import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/flight_route_geometry.dart';
import 'package:beenaround/features/flights/presentation/widgets/flight_route_viewport.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const lisbon = Airport(
    id: 1,
    ident: 'LPPT',
    name: 'Lisbon Airport',
    type: 'large_airport',
    scheduledService: true,
    latitude: 38.7742,
    longitude: -9.1342,
  );

  const barcelona = Airport(
    id: 2,
    ident: 'LEBL',
    name: 'Barcelona Airport',
    type: 'large_airport',
    scheduledService: true,
    latitude: 41.2974,
    longitude: 2.0833,
  );

  const tokyo = Airport(
    id: 3,
    ident: 'RJTT',
    name: 'Tokyo Haneda Airport',
    type: 'large_airport',
    scheduledService: true,
    latitude: 35.5494,
    longitude: 139.7798,
  );

  const losAngeles = Airport(
    id: 4,
    ident: 'KLAX',
    name: 'Los Angeles International Airport',
    type: 'large_airport',
    scheduledService: true,
    latitude: 33.9416,
    longitude: -118.4085,
  );

  FlightRouteViewport? viewportBetween(
    Airport departure,
    Airport arrival, {
    double width = 390,
    double height = 240,
  }) {
    return FlightRouteViewportCalculator.calculate(
      points: FlightRouteGeometry.between(departure, arrival),
      width: width,
      height: height,
    );
  }

  group('FlightRouteViewportCalculator', () {
    test('centers Lisbon to Barcelona over the route', () {
      final viewport = viewportBetween(lisbon, barcelona);

      expect(viewport, isNotNull);

      expect(viewport!.latitude, inInclusiveRange(38, 43));

      expect(viewport.longitude, inInclusiveRange(-10, 3));

      expect(viewport.zoom, inInclusiveRange(0.5, 9));
    });

    test('uses the inverse Web Mercator projection', () {
      final viewport = FlightRouteViewportCalculator.calculate(
        points: const [
          FlightRoutePoint(latitude: 40, longitude: -10),
          FlightRoutePoint(latitude: 40, longitude: 10),
        ],
        width: 390,
        height: 240,
      );

      expect(viewport, isNotNull);

      // Both points share latitude 40.
      // The calculated center must retain that latitude.
      expect(viewport!.latitude, closeTo(40, 0.000001));

      expect(viewport.longitude, closeTo(0, 0.000001));
    });

    test('handles routes crossing the antimeridian', () {
      final viewport = viewportBetween(tokyo, losAngeles);

      expect(viewport, isNotNull);

      // The route crosses the Pacific.
      // Its center must not jump towards Europe.
      expect(viewport!.longitude.abs(), greaterThan(150));

      expect(viewport.zoom, inInclusiveRange(0.5, 9));
    });

    test('uses a smaller zoom on a narrower viewport', () {
      final narrow = viewportBetween(lisbon, barcelona, width: 320);

      final wide = viewportBetween(lisbon, barcelona, width: 800);

      expect(narrow, isNotNull);
      expect(wide, isNotNull);

      expect(narrow!.zoom, lessThanOrEqualTo(wide!.zoom));
    });

    test('returns null for empty route geometry', () {
      final viewport = FlightRouteViewportCalculator.calculate(
        points: const [],
        width: 390,
        height: 240,
      );

      expect(viewport, isNull);
    });

    test('rejects invalid viewport dimensions', () {
      final points = FlightRouteGeometry.between(lisbon, barcelona);

      expect(
        FlightRouteViewportCalculator.calculate(
          points: points,
          width: 0,
          height: 240,
        ),
        isNull,
      );

      expect(
        FlightRouteViewportCalculator.calculate(
          points: points,
          width: 390,
          height: -1,
        ),
        isNull,
      );
    });

    test('rejects invalid coordinates', () {
      final viewport = FlightRouteViewportCalculator.calculate(
        points: const [FlightRoutePoint(latitude: 100, longitude: 0)],
        width: 390,
        height: 240,
      );

      expect(viewport, isNull);
    });
  });
}
