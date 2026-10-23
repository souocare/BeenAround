import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/country_geometry_bounds.dart';
import 'package:beenaround/features/map/domain/country_map_viewport.dart';

void main() {
  group('CountryMapViewport', () {
    CountryMapViewport calculateViewport(CountryGeometryBounds bounds) {
      return calculateCountryMapViewport(
        bounds: bounds,
        width: 360,
        height: 220,
      );
    }

    void expectValidViewport(
      CountryMapViewport viewport,
      CountryGeometryBounds bounds,
    ) {
      expect(viewport.longitude.isFinite, isTrue);
      expect(viewport.latitude.isFinite, isTrue);
      expect(viewport.zoom.isFinite, isTrue);

      expect(viewport.longitude, inInclusiveRange(bounds.west, bounds.east));

      expect(viewport.latitude, inInclusiveRange(bounds.south, bounds.north));

      expect(viewport.zoom, inInclusiveRange(1.0, 14.0));
    }

    test('calculates a valid viewport for Spain', () {
      const bounds = CountryGeometryBounds(
        west: -9.5,
        east: 3.5,
        south: 35.5,
        north: 44.0,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);

      expect(viewport.longitude, closeTo(-3.0, 0.01));
    });

    test('calculates a valid viewport for Norway', () {
      const bounds = CountryGeometryBounds(
        west: -9.11742,
        east: 31.077,
        south: 57.99315,
        north: 71.18037,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);

      expect(viewport.longitude, closeTo(10.97979, 0.00001));
      expect(viewport.latitude, closeTo(65.401955, 0.001));
    });

    test('calculates a valid viewport for Maldives', () {
      const bounds = CountryGeometryBounds(
        west: 72.0,
        east: 74.0,
        south: -1.0,
        north: 8.0,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);
    });

    test('smaller countries receive a higher zoom', () {
      const spain = CountryGeometryBounds(
        west: -9.5,
        east: 3.5,
        south: 35.5,
        north: 44.0,
      );

      const singapore = CountryGeometryBounds(
        west: 103.6,
        east: 104.1,
        south: 1.1,
        north: 1.5,
      );

      final spainViewport = calculateViewport(spain);
      final singaporeViewport = calculateViewport(singapore);

      expectValidViewport(spainViewport, spain);
      expectValidViewport(singaporeViewport, singapore);

      expect(singaporeViewport.zoom, greaterThan(spainViewport.zoom));
    });

    test('viewport center stays inside geographic bounds', () {
      const bounds = CountryGeometryBounds(
        west: -18.5,
        east: 4.5,
        south: 27.5,
        north: 44.0,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);
    });

    test('viewport values remain finite at high latitudes', () {
      const bounds = CountryGeometryBounds(
        west: 10.0,
        east: 30.0,
        south: 75.0,
        north: 84.0,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);
    });

    test('viewport values remain finite near the equator', () {
      const bounds = CountryGeometryBounds(
        west: 103.6,
        east: 104.1,
        south: 1.1,
        north: 1.5,
      );

      final viewport = calculateViewport(bounds);

      expectValidViewport(viewport, bounds);
    });

    test('zoom respects minimum and maximum limits', () {
      const largeBounds = CountryGeometryBounds(
        west: -170.0,
        east: 170.0,
        south: -80.0,
        north: 80.0,
      );

      const tinyBounds = CountryGeometryBounds(
        west: 10.0,
        east: 10.000001,
        south: 20.0,
        north: 20.000001,
      );

      final largeViewport = calculateViewport(largeBounds);
      final tinyViewport = calculateViewport(tinyBounds);

      expect(largeViewport.zoom, 1.0);
      expect(tinyViewport.zoom, 14.0);

      expectValidViewport(largeViewport, largeBounds);
      expectValidViewport(tinyViewport, tinyBounds);
    });
  });
}
