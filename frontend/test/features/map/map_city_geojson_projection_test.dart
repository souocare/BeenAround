import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_city_geojson_projection.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';

MapCityData makeCity({
  required int id,
  required String name,
  required double latitude,
  required double longitude,
  String countryCode = 'PT',
  int visitCount = 1,
  int residenceCount = 0,
  bool isWishlisted = false,
}) {
  return MapCityData(
    cityId: id,
    name: name,
    countryCode: countryCode,
    countryName: countryCode,
    latitude: latitude,
    longitude: longitude,
    visitCount: visitCount,
    residenceCount: residenceCount,
    isWishlisted: isWishlisted,
  );
}

Map<String, dynamic> decodeCollection(String geoJson) {
  return jsonDecode(geoJson) as Map<String, dynamic>;
}

void main() {
  group('buildMapCityGeoJson', () {
    test('returns an empty FeatureCollection for no cities', () {
      final result = decodeCollection(buildMapCityGeoJson(cities: const []));

      expect(result['type'], 'FeatureCollection');
      expect(result['features'], isEmpty);
    });

    test('creates one Point feature per city', () {
      final result = decodeCollection(
        buildMapCityGeoJson(
          cities: [
            makeCity(
              id: 1,
              name: 'Lisbon',
              latitude: 38.7223,
              longitude: -9.1393,
            ),
            makeCity(
              id: 2,
              name: 'Madrid',
              countryCode: 'ES',
              latitude: 40.4168,
              longitude: -3.7038,
            ),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(2));

      expect(features[0]['id'], 1);
      expect(features[1]['id'], 2);

      expect(features[0]['geometry']['type'], 'Point');

      expect(features[0]['geometry']['coordinates'], [-9.1393, 38.7223]);
    });

    test('preserves geographic identity and travel metadata', () {
      final result = decodeCollection(
        buildMapCityGeoJson(
          cities: [
            makeCity(
              id: 10,
              name: 'Barcelona',
              countryCode: 'ES',
              latitude: 41.3874,
              longitude: 2.1686,
              visitCount: 3,
              residenceCount: 2,
              isWishlisted: true,
            ),
          ],
        ),
      );

      final feature = (result['features'] as List<dynamic>).single;

      final properties = feature['properties'] as Map<String, dynamic>;

      expect(properties['city_id'], 10);
      expect(properties['name'], 'Barcelona');
      expect(properties['country_code'], 'ES');

      expect(properties['visit_count'], 3);
      expect(properties['residence_count'], 2);
      expect(properties['is_wishlisted'], isTrue);
    });

    test('sorts cities by catalog ID', () {
      final result = decodeCollection(
        buildMapCityGeoJson(
          cities: [
            makeCity(id: 30, name: 'City C', latitude: 10, longitude: 10),
            makeCity(id: 10, name: 'City A', latitude: 20, longitude: 20),
            makeCity(id: 20, name: 'City B', latitude: 30, longitude: 30),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features.map((feature) => feature['id']).toList(), [10, 20, 30]);
    });

    test('produces identical output regardless of input order', () {
      final lisbon = makeCity(
        id: 1,
        name: 'Lisbon',
        latitude: 38.7223,
        longitude: -9.1393,
      );

      final madrid = makeCity(
        id: 2,
        name: 'Madrid',
        countryCode: 'ES',
        latitude: 40.4168,
        longitude: -3.7038,
      );

      final first = buildMapCityGeoJson(cities: [lisbon, madrid]);

      final second = buildMapCityGeoJson(cities: [madrid, lisbon]);

      expect(first, second);
    });

    test('does not depend on the city name being unique', () {
      final result = decodeCollection(
        buildMapCityGeoJson(
          cities: [
            makeCity(
              id: 100,
              name: 'Springfield',
              latitude: 39,
              longitude: -89,
              countryCode: 'US',
            ),
            makeCity(
              id: 200,
              name: 'Springfield',
              latitude: 44,
              longitude: -79,
              countryCode: 'CA',
            ),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(2));
      expect(features[0]['id'], 100);
      expect(features[1]['id'], 200);
    });
  });
}
