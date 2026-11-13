import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/flight_distance.dart';

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

  test('calculates great-circle distance between airports', () {
    final distance = FlightDistance.between(lisbon, barcelona);

    expect(distance, isNotNull);

    // Approximate geographic distance, not actual flown distance.
    expect(distance!, greaterThan(990));
    expect(distance, lessThan(1010));
  });

  test('returns zero for identical coordinates', () {
    final distance = FlightDistance.between(lisbon, lisbon);

    expect(distance, closeTo(0, 0.001));
  });

  test('returns null when coordinates are missing', () {
    const unknown = Airport(
      id: 3,
      ident: 'UNKNOWN',
      name: 'Unknown Airport',
      type: 'small_airport',
      scheduledService: false,
    );

    expect(FlightDistance.between(lisbon, unknown), isNull);
    expect(FlightDistance.between(null, barcelona), isNull);
  });

  test('returns null for invalid coordinates', () {
    const invalid = Airport(
      id: 4,
      ident: 'INVALID',
      name: 'Invalid Airport',
      type: 'small_airport',
      scheduledService: false,
      latitude: 95,
      longitude: 200,
    );

    expect(FlightDistance.between(lisbon, invalid), isNull);
  });

  test('distance is symmetrical', () {
    final outbound = FlightDistance.between(lisbon, barcelona);
    final inbound = FlightDistance.between(barcelona, lisbon);

    expect(outbound, isNotNull);
    expect(inbound, closeTo(outbound!, 0.001));
  });
}
