import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

import 'package:beenaround/features/map/application/map_camera_target.dart';

void main() {
  group('calculateMapCameraTarget', () {
    test('calculates a valid camera for Spain', () {
      final target = calculateMapCameraTarget(
        bounds: LngLatBounds(
          longitudeWest: -9,
          longitudeEast: 3,
          latitudeSouth: 36,
          latitudeNorth: 44,
        ),
        viewportSize: const Size(390, 844),
        padding: const EdgeInsets.fromLTRB(55, 100, 55, 135),
      );

      expect(target.center.lon, closeTo(-3, 1));
      expect(target.center.lat, closeTo(40, 2));

      expect(target.zoom, greaterThan(2));
      expect(target.zoom, lessThan(5.5));
    });

    test('prevents excessive zoom for very small countries', () {
      final target = calculateMapCameraTarget(
        bounds: LngLatBounds(
          longitudeWest: 7.4,
          longitudeEast: 7.5,
          latitudeSouth: 43.7,
          latitudeNorth: 43.8,
        ),
        viewportSize: const Size(390, 844),
        maxZoom: 5.5,
      );

      expect(target.zoom, 5.5);
    });

    test('uses a wider geographic view for large countries', () {
      final small = calculateMapCameraTarget(
        bounds: LngLatBounds(
          longitudeWest: -9,
          longitudeEast: 3,
          latitudeSouth: 36,
          latitudeNorth: 44,
        ),
        viewportSize: const Size(390, 844),
      );

      final large = calculateMapCameraTarget(
        bounds: LngLatBounds(
          longitudeWest: -74,
          longitudeEast: -34,
          latitudeSouth: -34,
          latitudeNorth: 5,
        ),
        viewportSize: const Size(390, 844),
      );

      expect(large.zoom, lessThan(small.zoom));
    });

    test('rejects padding larger than the viewport', () {
      expect(
        () => calculateMapCameraTarget(
          bounds: LngLatBounds(
            longitudeWest: -9,
            longitudeEast: 3,
            latitudeSouth: 36,
            latitudeNorth: 44,
          ),
          viewportSize: const Size(100, 100),
          padding: const EdgeInsets.all(80),
        ),
        throwsArgumentError,
      );
    });
  });
}
