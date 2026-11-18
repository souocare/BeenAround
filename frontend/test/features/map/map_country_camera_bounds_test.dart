import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_country_camera_bounds.dart';

void main() {
  group('calculateCountryCameraBounds', () {
    test('calculates bounds for a simple country polygon', () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"country_code": "ES"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[
                [-9, 36],
                [3, 36],
                [3, 44],
                [-9, 44],
                [-9, 36]
              ]]
            }
          }
        ]
      }
      ''';

      final bounds = calculateCountryCameraBounds(
        countryGeoJson: geoJson,
        tappedLatitude: 40,
        tappedLongitude: -3,
      );

      expect(bounds, isNotNull);

      expect(bounds!.longitudeWest, -9);
      expect(bounds.longitudeEast, 3);
      expect(bounds.latitudeSouth, 36);
      expect(bounds.latitudeNorth, 44);
    });

    test('uses a minimum area for very small countries', () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"country_code": "MC"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[
                [7.4, 43.7],
                [7.5, 43.7],
                [7.5, 43.8],
                [7.4, 43.8],
                [7.4, 43.7]
              ]]
            }
          }
        ]
      }
      ''';

      final bounds = calculateCountryCameraBounds(
        countryGeoJson: geoJson,
        tappedLatitude: 43.75,
        tappedLongitude: 7.45,
      );

      expect(bounds, isNotNull);

      expect(bounds!.longitudeEast - bounds.longitudeWest, closeTo(8, 0.001));

      expect(bounds.latitudeNorth - bounds.latitudeSouth, closeTo(6, 0.001));
    });

    test('selects the tapped region of a multipolygon country', () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"country_code": "PT"},
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [
                [[
                  [-10, 37],
                  [-6, 37],
                  [-6, 42],
                  [-10, 42],
                  [-10, 37]
                ]],
                [[
                  [-29, 38],
                  [-24, 38],
                  [-24, 40],
                  [-29, 40],
                  [-29, 38]
                ]]
              ]
            }
          }
        ]
      }
      ''';

      final bounds = calculateCountryCameraBounds(
        countryGeoJson: geoJson,
        tappedLatitude: 39,
        tappedLongitude: -8,
      );

      expect(bounds, isNotNull);

      // Mainland Portugal was tapped, so distant islands should
      // not affect the camera.
      expect(bounds!.longitudeWest, greaterThan(-20));
      expect(bounds.longitudeEast, lessThan(0));
    });

    test('returns null when no country geometry exists', () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": []
      }
      ''';

      final bounds = calculateCountryCameraBounds(
        countryGeoJson: geoJson,
        tappedLatitude: 0,
        tappedLongitude: 0,
      );

      expect(bounds, isNull);
    });
  });
}
