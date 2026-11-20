import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_airport_visibility.dart';
import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';

MapAirportData makeAirport({
  required int id,
  required double latitude,
  required double longitude,
}) {
  return MapAirportData(
    airportId: id,
    code: 'APT$id',
    name: 'Airport $id',
    countryCode: 'PT',
    latitude: latitude,
    longitude: longitude,
    departureCount: 1,
    arrivalCount: 0,
    flightCount: 1,
  );
}

MapCityData makeCity({
  required int id,
  required double latitude,
  required double longitude,
}) {
  return MapCityData(
    cityId: id,
    name: 'City $id',
    countryCode: 'PT',
    countryName: 'Portugal',
    latitude: latitude,
    longitude: longitude,
    visitCount: 1,
    residenceCount: 0,
    isWishlisted: false,
  );
}

void main() {
  group('calculateVisibleMapAirports', () {
    final lisbon = makeCity(id: 1, latitude: 38.7223, longitude: -9.1393);

    final lisbonAirport = makeAirport(
      id: 10,
      latitude: 38.7742,
      longitude: -9.1342,
    );

    test('keeps airports visible when no cities are present', () {
      final result = calculateVisibleMapAirports(
        airports: [lisbonAirport],
        visibleCities: const [],
        zoom: 3,
      );

      expect(result, [lisbonAirport]);
    });

    test('hides nearby airport at low zoom', () {
      final result = calculateVisibleMapAirports(
        airports: [lisbonAirport],
        visibleCities: [lisbon],
        zoom: 4,
      );

      expect(result, isEmpty);
    });

    test('shows nearby airport at high zoom', () {
      final result = calculateVisibleMapAirports(
        airports: [lisbonAirport],
        visibleCities: [lisbon],
        zoom: 12,
      );

      expect(result, [lisbonAirport]);
    });

    test('keeps geographically distant airports visible', () {
      final madeiraAirport = makeAirport(
        id: 20,
        latitude: 32.6979,
        longitude: -16.7745,
      );

      final result = calculateVisibleMapAirports(
        airports: [lisbonAirport, madeiraAirport],
        visibleCities: [lisbon],
        zoom: 4,
      );

      expect(result, [madeiraAirport]);
    });

    test('does not alter the original airport collection', () {
      final airports = [lisbonAirport];

      calculateVisibleMapAirports(
        airports: airports,
        visibleCities: [lisbon],
        zoom: 4,
      );

      expect(airports, [lisbonAirport]);
    });

    test('returns an unmodifiable list', () {
      final result = calculateVisibleMapAirports(
        airports: [lisbonAirport],
        visibleCities: const [],
        zoom: 4,
      );

      expect(() => result.clear(), throwsUnsupportedError);
    });

    test('handles positions across the antimeridian', () {
      final city = makeCity(id: 1, latitude: 0, longitude: 179.99);

      final airport = makeAirport(id: 10, latitude: 0, longitude: -179.99);

      final result = calculateVisibleMapAirports(
        airports: [airport],
        visibleCities: [city],
        zoom: 4,
      );

      expect(result, isEmpty);
    });
  });

  group('calculateMapMarkerDistance', () {
    test('returns zero for identical coordinates', () {
      final distance = calculateMapMarkerDistance(
        firstLatitude: 38.7223,
        firstLongitude: -9.1393,
        secondLatitude: 38.7223,
        secondLongitude: -9.1393,
        zoom: 5,
      );

      expect(distance, closeTo(0, 0.000001));
    });

    test('increases as zoom increases', () {
      double distanceAt(double zoom) {
        return calculateMapMarkerDistance(
          firstLatitude: 38.7223,
          firstLongitude: -9.1393,
          secondLatitude: 38.7742,
          secondLongitude: -9.1342,
          zoom: zoom,
        );
      }

      expect(distanceAt(12), greaterThan(distanceAt(4)));
    });
  });
}
