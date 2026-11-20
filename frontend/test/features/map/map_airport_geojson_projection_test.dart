import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_airport_geojson_projection.dart';
import 'package:beenaround/features/map/domain/map_airport_data.dart';

MapAirportData makeAirport({
  required int id,
  required String code,
  required double latitude,
  required double longitude,
  String? countryCode = 'PT',
  int departureCount = 1,
  int arrivalCount = 0,
  int flightCount = 1,
}) {
  return MapAirportData(
    airportId: id,
    code: code,
    name: '$code Airport',
    countryCode: countryCode,
    latitude: latitude,
    longitude: longitude,
    departureCount: departureCount,
    arrivalCount: arrivalCount,
    flightCount: flightCount,
  );
}

Map<String, dynamic> decodeCollection(String geoJson) {
  return jsonDecode(geoJson) as Map<String, dynamic>;
}

void main() {
  group('buildMapAirportGeoJson', () {
    test('returns an empty FeatureCollection without airports', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(airports: const []),
      );

      expect(result['type'], 'FeatureCollection');
      expect(result['features'], isEmpty);
    });

    test('creates one Point feature per airport', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(
          airports: [
            makeAirport(
              id: 1,
              code: 'LIS',
              latitude: 38.7742,
              longitude: -9.1342,
            ),
            makeAirport(
              id: 2,
              code: 'FNC',
              latitude: 32.6979,
              longitude: -16.7745,
            ),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(2));

      expect(features[0]['id'], 1);
      expect(features[1]['id'], 2);

      expect(features[0]['geometry']['type'], 'Point');

      // GeoJSON uses longitude before latitude.
      expect(features[0]['geometry']['coordinates'], [-9.1342, 38.7742]);

      expect(features[1]['geometry']['coordinates'], [-16.7745, 32.6979]);
    });

    test('preserves airport identity and flight metadata', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(
          airports: [
            makeAirport(
              id: 10,
              code: 'LIS',
              latitude: 38.7742,
              longitude: -9.1342,
              departureCount: 5,
              arrivalCount: 3,
              flightCount: 8,
            ),
          ],
        ),
      );

      final feature = (result['features'] as List<dynamic>).single;

      final properties = feature['properties'] as Map<String, dynamic>;

      expect(properties['airport_id'], 10);
      expect(properties['code'], 'LIS');
      expect(properties['name'], 'LIS Airport');
      expect(properties['country_code'], 'PT');

      expect(properties['departure_count'], 5);
      expect(properties['arrival_count'], 3);
      expect(properties['flight_count'], 8);
    });

    test('supports airports without a country code', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(
          airports: [
            makeAirport(
              id: 1,
              code: 'ABC',
              latitude: 10,
              longitude: 20,
              countryCode: null,
            ),
          ],
        ),
      );

      final feature = (result['features'] as List<dynamic>).single;

      expect(feature['properties']['country_code'], isNull);
    });

    test('sorts airports by catalog ID', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(
          airports: [
            makeAirport(id: 30, code: 'FNC', latitude: 32, longitude: -16),
            makeAirport(id: 10, code: 'LIS', latitude: 38, longitude: -9),
            makeAirport(id: 20, code: 'OPO', latitude: 41, longitude: -8),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features.map((feature) => feature['id']).toList(), [10, 20, 30]);
    });

    test('produces identical output regardless of input order', () {
      final lisbon = makeAirport(
        id: 1,
        code: 'LIS',
        latitude: 38.7742,
        longitude: -9.1342,
      );

      final madeira = makeAirport(
        id: 2,
        code: 'FNC',
        latitude: 32.6979,
        longitude: -16.7745,
      );

      final first = buildMapAirportGeoJson(airports: [lisbon, madeira]);

      final second = buildMapAirportGeoJson(airports: [madeira, lisbon]);

      expect(first, second);
    });

    test('distinguishes airports by ID rather than display code', () {
      final result = decodeCollection(
        buildMapAirportGeoJson(
          airports: [
            makeAirport(id: 100, code: 'ABC', latitude: 10, longitude: 20),
            makeAirport(id: 200, code: 'ABC', latitude: 30, longitude: 40),
          ],
        ),
      );

      final features = result['features'] as List<dynamic>;

      expect(features, hasLength(2));

      expect(features[0]['id'], 100);
      expect(features[1]['id'], 200);
    });

    test('does not modify the input collection', () {
      final airports = [
        makeAirport(id: 2, code: 'FNC', latitude: 32, longitude: -16),
        makeAirport(id: 1, code: 'LIS', latitude: 38, longitude: -9),
      ];

      buildMapAirportGeoJson(airports: airports);

      expect(airports.map((airport) => airport.airportId).toList(), [2, 1]);
    });
  });
}
