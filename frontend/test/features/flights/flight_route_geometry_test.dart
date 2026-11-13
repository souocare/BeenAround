import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/flight_route_geometry.dart';

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

  test('generates a great-circle route with intermediate points', () {
    final route = FlightRouteGeometry.between(lisbon, barcelona);

    expect(route.length, 65);

    expect(route.first.latitude, closeTo(lisbon.latitude!, 0.000001));

    expect(route.first.longitude, closeTo(lisbon.longitude!, 0.000001));

    expect(route.last.latitude, closeTo(barcelona.latitude!, 0.000001));

    expect(route.last.longitude, closeTo(barcelona.longitude!, 0.000001));
  });

  test('returns no route when coordinates are missing', () {
    const unknown = Airport(
      id: 3,
      ident: 'UNKNOWN',
      name: 'Unknown Airport',
      type: 'small_airport',
      scheduledService: false,
    );

    expect(FlightRouteGeometry.between(lisbon, unknown), isEmpty);
  });

  test('returns no route for invalid coordinates', () {
    const invalid = Airport(
      id: 4,
      ident: 'INVALID',
      name: 'Invalid Airport',
      type: 'small_airport',
      scheduledService: false,
      latitude: 100,
      longitude: 200,
    );

    expect(FlightRouteGeometry.between(lisbon, invalid), isEmpty);
  });

  test('supports a configurable number of segments', () {
    final route = FlightRouteGeometry.between(lisbon, barcelona, segments: 10);

    expect(route.length, 11);
  });

  test('rejects zero segments', () {
    expect(
      () => FlightRouteGeometry.between(lisbon, barcelona, segments: 0),
      throwsArgumentError,
    );
  });
}
