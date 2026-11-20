import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_selected_airport_visibility.dart';
import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';

MapAirportData makeAirport(int id, String code) {
  return MapAirportData(
    airportId: id,
    code: code,
    name: '$code Airport',
    countryCode: 'PT',
    latitude: 38.7742,
    longitude: -9.1342,
    departureCount: 1,
    arrivalCount: 1,
    flightCount: 2,
  );
}

void main() {
  final lisbon = makeAirport(10, 'LIS');
  final madeira = makeAirport(20, 'FNC');

  group('selectedUsedAirportId', () {
    test('identifies a selected airport from completed flights', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:10',
        title: 'Lisbon Airport',
        subtitle: 'LIS',
      );

      final result = selectedUsedAirportId(
        selectedDestination: destination,
        usedAirports: [lisbon, madeira],
      );

      expect(result, 10);
    });

    test('does not classify an unused airport as used', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:999',
        title: 'Other Airport',
        subtitle: 'ABC',
      );

      final result = selectedUsedAirportId(
        selectedDestination: destination,
        usedAirports: [lisbon],
      );

      expect(result, isNull);
    });

    test('ignores selected cities', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:10',
        title: 'Lisbon',
        subtitle: 'Portugal',
      );

      expect(
        selectedUsedAirportId(
          selectedDestination: destination,
          usedAirports: [lisbon],
        ),
        isNull,
      );
    });

    test('handles invalid airport IDs safely', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:invalid',
        title: 'Invalid Airport',
        subtitle: '',
      );

      expect(
        selectedUsedAirportId(
          selectedDestination: destination,
          usedAirports: [lisbon],
        ),
        isNull,
      );
    });
  });

  group('excludeSelectedMapAirport', () {
    test('excludes only the selected airport', () {
      final result = excludeSelectedMapAirport(
        airports: [lisbon, madeira],
        selectedAirportId: 10,
      );

      expect(result, [madeira]);
    });

    test('preserves all airports when none is selected', () {
      final result = excludeSelectedMapAirport(
        airports: [lisbon, madeira],
        selectedAirportId: null,
      );

      expect(result, [lisbon, madeira]);
    });

    test('does not modify the original collection', () {
      final airports = [lisbon, madeira];

      excludeSelectedMapAirport(airports: airports, selectedAirportId: 10);

      expect(airports, [lisbon, madeira]);
    });

    test('returns an unmodifiable collection', () {
      final result = excludeSelectedMapAirport(
        airports: [lisbon],
        selectedAirportId: null,
      );

      expect(() => result.clear(), throwsUnsupportedError);
    });
  });
}
