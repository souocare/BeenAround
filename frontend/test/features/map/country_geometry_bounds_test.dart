import 'package:beenaround/features/map/data/world_country_loader.dart';
import 'package:beenaround/features/map/domain/country_geometry_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateCountryBounds', () {
    test('calculates bounds for a single polygon', () {
      const geometry = WorldCountryGeometry(
        countryCode: 'PT',
        polygons: [
          [
            [
              [-9.5, 37.0],
              [-6.2, 37.0],
              [-6.2, 42.2],
              [-9.5, 42.2],
            ],
          ],
        ],
      );

      final bounds = calculateCountryBounds(geometry);

      expect(bounds, isNotNull);
      expect(bounds!.west, -9.5);
      expect(bounds.south, 37.0);
      expect(bounds.east, -6.2);
      expect(bounds.north, 42.2);
    });

    test('includes all polygons in a multipolygon', () {
      const geometry = WorldCountryGeometry(
        countryCode: 'PT',
        polygons: [
          [
            [
              [-9.5, 37.0],
              [-6.2, 42.2],
            ],
          ],
          [
            [
              [-25.0, 37.0],
              [-24.0, 38.0],
            ],
          ],
        ],
      );

      final bounds = calculateCountryBounds(geometry);

      expect(bounds!.west, -25.0);
      expect(bounds.east, -6.2);
      expect(bounds.south, 37.0);
      expect(bounds.north, 42.2);
    });

    test('returns null for empty geometry', () {
      const geometry = WorldCountryGeometry(countryCode: 'PT', polygons: []);

      expect(calculateCountryBounds(geometry), isNull);
    });

    test('rejects invalid coordinates', () {
      const geometry = WorldCountryGeometry(
        countryCode: 'PT',
        polygons: [
          [
            [
              [200.0, 38.0],
            ],
          ],
        ],
      );

      expect(() => calculateCountryBounds(geometry), throwsFormatException);
    });
  });
}
