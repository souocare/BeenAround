import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_country_camera_bounds.dart';

void main() {
  final multiRegionCountry = jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {'country_code': 'XX'},
        'geometry': {
          'type': 'MultiPolygon',
          'coordinates': [
            // Main region: 20 x 15 degrees.
            [
              [
                [-10, 30],
                [10, 30],
                [10, 45],
                [-10, 45],
                [-10, 30],
              ],
            ],

            // Small western island.
            [
              [
                [-50, 35],
                [-47, 35],
                [-47, 38],
                [-50, 38],
                [-50, 35],
              ],
            ],

            // Small eastern island.
            [
              [
                [70, 10],
                [72, 10],
                [72, 12],
                [70, 12],
                [70, 10],
              ],
            ],
          ],
        },
      },
    ],
  });

  group('calculateCountrySearchCameraBounds', () {
    test('selects the largest polygon for a searched country', () {
      final bounds = calculateCountrySearchCameraBounds(
        countryGeoJson: multiRegionCountry,
      );

      expect(bounds, isNotNull);

      expect(bounds!.longitudeWest, -10);
      expect(bounds.longitudeEast, 10);

      expect(bounds.latitudeSouth, 30);
      expect(bounds.latitudeNorth, 45);
    });

    test('does not include distant islands in the main region', () {
      final bounds = calculateCountrySearchCameraBounds(
        countryGeoJson: multiRegionCountry,
      );

      expect(bounds, isNotNull);

      expect(bounds!.longitudeWest, greaterThan(-47));
      expect(bounds.longitudeEast, lessThan(70));
    });

    test('preserves the existing map-tap selection behavior', () {
      final bounds = calculateCountryCameraBounds(
        countryGeoJson: multiRegionCountry,
        tappedLatitude: 36,
        tappedLongitude: -49,
      );

      expect(bounds, isNotNull);

      // The western island is selected.
      //
      // Its original span is 3 x 3 degrees,
      // expanded to the minimum camera dimensions.
      expect(bounds!.longitudeWest, -52.5);
      expect(bounds.longitudeEast, -44.5);

      expect(bounds.latitudeSouth, 33.5);
      expect(bounds.latitudeNorth, 39.5);
    });

    test('applies minimum camera dimensions to a small country', () {
      final smallCountry = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0, 0],
                  [1, 0],
                  [1, 1],
                  [0, 1],
                  [0, 0],
                ],
              ],
            },
          },
        ],
      });

      final bounds = calculateCountrySearchCameraBounds(
        countryGeoJson: smallCountry,
      );

      expect(bounds, isNotNull);

      expect(
        bounds!.latitudeNorth - bounds.latitudeSouth,
        closeTo(6, 0.000001),
      );

      expect(bounds.longitudeEast - bounds.longitudeWest, closeTo(8, 0.000001));
    });

    test('returns null for an empty feature collection', () {
      final bounds = calculateCountrySearchCameraBounds(
        countryGeoJson: jsonEncode({
          'type': 'FeatureCollection',
          'features': [],
        }),
      );

      expect(bounds, isNull);
    });

    test('throws FormatException for an invalid GeoJSON root', () {
      expect(
        () => calculateCountrySearchCameraBounds(countryGeoJson: '[]'),
        throwsFormatException,
      );
    });
  });
}
