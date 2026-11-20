import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_search_selection_geojson.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';
import 'dart:convert';

void main() {
  Map<String, dynamic> decode(String geoJson) {
    return jsonDecode(geoJson) as Map<String, dynamic>;
  }

  group('buildMapSearchSelectionGeoJson', () {
    test('returns an empty collection without a selection', () {
      final result = decode(buildMapSearchSelectionGeoJson(destination: null));

      expect(result['type'], 'FeatureCollection');
      expect(result['features'], isEmpty);
    });

    test('does not create point markers for countries', () {
      final destination = MapSearchDestination.country(
        code: 'JP',
        name: 'Japan',
      );

      final result = decode(
        buildMapSearchSelectionGeoJson(destination: destination),
      );

      expect(result['features'], isEmpty);
    });

    test('creates a point for a catalog city', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:123',
        title: 'Tokyo',
        subtitle: 'Japan',
        countryCode: 'JP',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      final result = decode(
        buildMapSearchSelectionGeoJson(destination: destination),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(1));

      final feature = features.single as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      expect(feature['id'], 'city:123');
      expect(properties['destination_id'], 'city:123');
      expect(properties['destination_type'], 'city');
      expect(properties['name'], 'Tokyo');
      expect(properties['country_code'], 'JP');

      expect(geometry['type'], 'Point');
      expect(geometry['coordinates'], [139.6503, 35.6762]);
    });

    test('creates a point for a catalog airport', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:456',
        title: 'Humberto Delgado Airport',
        subtitle: 'LIS · Lisbon, Portugal',
        countryCode: 'PT',
        latitude: 38.7742,
        longitude: -9.1342,
      );

      final result = decode(
        buildMapSearchSelectionGeoJson(destination: destination),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(1));

      final feature = features.single as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      expect(feature['id'], 'airport:456');
      expect(properties['destination_type'], 'airport');
      expect(geometry['coordinates'], [-9.1342, 38.7742]);
    });

    test('does not create a marker without coordinates', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:789',
        title: 'Unknown Airport',
        subtitle: 'Unknown location',
      );

      final result = decode(
        buildMapSearchSelectionGeoJson(destination: destination),
      );

      expect(result['features'], isEmpty);
    });

    test('does not create a marker with invalid coordinates', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:999',
        title: 'Invalid City',
        subtitle: 'Unknown',
        latitude: 120,
        longitude: 200,
      );

      final result = decode(
        buildMapSearchSelectionGeoJson(destination: destination),
      );

      expect(result['features'], isEmpty);
    });

    test('preserves destination type in feature properties', () {
      const city = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:1',
        title: 'Madrid',
        subtitle: 'Spain',
        latitude: 40.4168,
        longitude: -3.7038,
      );

      const airport = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:1',
        title: 'Madrid Airport',
        subtitle: 'MAD · Madrid, Spain',
        latitude: 40.4722,
        longitude: -3.5608,
      );

      final cityResult = decode(
        buildMapSearchSelectionGeoJson(destination: city),
      );

      final airportResult = decode(
        buildMapSearchSelectionGeoJson(destination: airport),
      );

      final cityFeature =
          (cityResult['features'] as List<dynamic>).single
              as Map<String, dynamic>;

      final airportFeature =
          (airportResult['features'] as List<dynamic>).single
              as Map<String, dynamic>;

      expect(
        (cityFeature['properties'] as Map<String, dynamic>)['destination_type'],
        'city',
      );

      expect(
        (airportFeature['properties']
            as Map<String, dynamic>)['destination_type'],
        'airport',
      );
    });
  });
  group('airport usage presentation metadata', () {
    const airport = MapSearchDestination(
      type: MapSearchDestinationType.airport,
      id: 'airport:10',
      title: 'Humberto Delgado Airport',
      subtitle: 'LIS',
      latitude: 38.7742,
      longitude: -9.1342,
      airportCode: 'LIS',
    );

    test('marks a completed-flight airport as used', () {
      final geoJson = buildMapSearchSelectionGeoJson(
        destination: airport,
        isUsedAirport: true,
      );

      final collection = jsonDecode(geoJson) as Map<String, dynamic>;

      final feature = (collection['features'] as List<dynamic>).single;

      expect(feature['properties']['is_used_airport'], isTrue);
    });

    test('keeps an unused airport neutral', () {
      final geoJson = buildMapSearchSelectionGeoJson(destination: airport);

      final collection = jsonDecode(geoJson) as Map<String, dynamic>;

      final feature = (collection['features'] as List<dynamic>).single;

      expect(feature['properties']['is_used_airport'], isFalse);
    });

    test('does not classify a city as a used airport', () {
      const city = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:20',
        title: 'Lisbon',
        subtitle: 'Portugal',
        latitude: 38.7223,
        longitude: -9.1393,
      );

      final geoJson = buildMapSearchSelectionGeoJson(
        destination: city,
        isUsedAirport: true,
      );

      final collection = jsonDecode(geoJson) as Map<String, dynamic>;

      final feature = (collection['features'] as List<dynamic>).single;

      expect(feature['properties']['is_used_airport'], isFalse);
    });
  });
}
