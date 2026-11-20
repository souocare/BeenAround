import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_city_panel_projection.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';

MapCityData makeCity({
  int id = 10,
  String name = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
  int visitCount = 0,
  int residenceCount = 0,
  bool isWishlisted = false,
}) {
  return MapCityData(
    cityId: id,
    name: name,
    countryCode: countryCode,
    countryName: countryName,
    latitude: 38.7223,
    longitude: -9.1393,
    visitCount: visitCount,
    residenceCount: residenceCount,
    isWishlisted: isWishlisted,
  );
}

void main() {
  group('buildMapCityPanelData', () {
    test('returns null without a selected city', () {
      final result = buildMapCityPanelData(city: null, destination: null);

      expect(result, isNull);
    });

    test('uses personal city data when available', () {
      final result = buildMapCityPanelData(
        city: makeCity(visitCount: 3, residenceCount: 1, isWishlisted: true),
        destination: null,
      );

      expect(result, isNotNull);

      expect(result!.cityId, 10);
      expect(result.name, 'Lisbon');
      expect(result.countryCode, 'PT');
      expect(result.countryName, 'Portugal');

      expect(result.visitCount, 3);
      expect(result.residenceCount, 1);
      expect(result.isWishlisted, isTrue);

      expect(result.hasVisited, isTrue);
      expect(result.hasLived, isTrue);
      expect(result.hasTravelHistory, isTrue);
      expect(result.hasAnyStatus, isTrue);
    });

    test('preserves personal history when selected through search', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:10',
        title: 'Lisbon',
        subtitle: 'Portugal',
        countryCode: 'PT',
      );

      final result = buildMapCityPanelData(
        city: makeCity(visitCount: 2, isWishlisted: true),
        destination: destination,
      );

      expect(result!.visitCount, 2);
      expect(result.isWishlisted, isTrue);
    });

    test('creates a catalog-only city without personal history', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:20',
        title: 'Tokyo',
        subtitle: 'Japan',
        countryCode: 'JP',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      final result = buildMapCityPanelData(
        city: null,
        destination: destination,
      );

      expect(result, isNotNull);

      expect(result!.cityId, 20);
      expect(result.name, 'Tokyo');
      expect(result.countryCode, 'JP');
      expect(result.countryName, 'Japan');

      expect(result.visitCount, 0);
      expect(result.residenceCount, 0);
      expect(result.isWishlisted, isFalse);

      expect(result.hasTravelHistory, isFalse);
      expect(result.hasAnyStatus, isFalse);
    });

    test('supports a wishlist-only city', () {
      final result = buildMapCityPanelData(
        city: makeCity(isWishlisted: true),
        destination: null,
      );

      expect(result!.hasVisited, isFalse);
      expect(result.hasLived, isFalse);
      expect(result.isWishlisted, isTrue);

      expect(result.hasTravelHistory, isFalse);
      expect(result.hasAnyStatus, isTrue);
    });

    test('rejects non-city catalog destinations', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:10',
        title: 'Lisbon Airport',
        subtitle: 'LIS',
      );

      expect(
        buildMapCityPanelData(city: null, destination: destination),
        isNull,
      );
    });

    test('rejects malformed catalog city IDs', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:invalid',
        title: 'Invalid City',
        subtitle: '',
      );

      expect(
        buildMapCityPanelData(city: null, destination: destination),
        isNull,
      );
    });
  });
}
