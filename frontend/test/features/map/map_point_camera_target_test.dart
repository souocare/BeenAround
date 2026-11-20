import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_camera_target.dart';

void main() {
  group('calculateMapPointCameraTarget', () {
    test('preserves coordinates when screen offset is zero', () {
      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: -3.7038,
        zoom: 4.5,
      );

      expect(target.center.lat, closeTo(40.4168, 0.000001));
      expect(target.center.lon, closeTo(-3.7038, 0.000001));
      expect(target.zoom, 4.5);
    });

    test('shifts the camera east when the target must appear left', () {
      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: -3.7038,
        zoom: 4.5,
        targetScreenOffset: const Offset(-180, 0),
      );

      // To display Madrid further left, the camera center
      // must move geographically east of Madrid.
      expect(target.center.lon, greaterThan(-3.7038));

      expect(target.center.lat, closeTo(40.4168, 0.000001));
      expect(target.zoom, 4.5);
    });

    test('shifts the camera west when the target must appear right', () {
      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: -3.7038,
        zoom: 4.5,
        targetScreenOffset: const Offset(180, 0),
      );

      expect(target.center.lon, lessThan(-3.7038));
    });

    test('shifts the camera south when target must appear above center', () {
      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: -3.7038,
        zoom: 4.5,
        targetScreenOffset: const Offset(0, -100),
      );

      expect(target.center.lat, lessThan(40.4168));
    });

    test('shifts the camera north when target must appear below center', () {
      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: -3.7038,
        zoom: 4.5,
        targetScreenOffset: const Offset(0, 100),
      );

      expect(target.center.lat, greaterThan(40.4168));
    });

    test('applies the requested horizontal offset in world pixels', () {
      const longitude = -3.7038;
      const zoom = 4.5;
      const requestedDx = -181.5;

      final target = calculateMapPointCameraTarget(
        latitude: 40.4168,
        longitude: longitude,
        zoom: zoom,
        targetScreenOffset: const Offset(requestedDx, 0),
      );

      final worldPixels = 512 * math.pow(2, zoom);

      final targetX = (longitude + 180) / 360;
      final cameraX = (target.center.lon + 180) / 360;

      final actualDx = (targetX - cameraX) * worldPixels;

      expect(actualDx, closeTo(requestedDx, 0.001));
    });

    test('preserves zoom regardless of target position', () {
      final target = calculateMapPointCameraTarget(
        latitude: 38.7742,
        longitude: -9.1342,
        zoom: 7.0,
        targetScreenOffset: const Offset(-150, 30),
      );

      expect(target.zoom, 7.0);
    });

    test('supports geographic locations near the antimeridian', () {
      final target = calculateMapPointCameraTarget(
        latitude: 35.0,
        longitude: 179.9,
        zoom: 5.0,
        targetScreenOffset: const Offset(-200, 0),
      );

      expect(target.center.lon, inInclusiveRange(-180.0, 180.0));
      expect(target.center.lat.isFinite, isTrue);
    });

    test('keeps high-latitude camera centers finite', () {
      final target = calculateMapPointCameraTarget(
        latitude: 80.0,
        longitude: 20.0,
        zoom: 4.5,
        targetScreenOffset: const Offset(-100, -80),
      );

      expect(target.center.lat.isFinite, isTrue);
      expect(target.center.lon.isFinite, isTrue);
    });

    test('rejects invalid latitude', () {
      expect(
        () => calculateMapPointCameraTarget(
          latitude: 91,
          longitude: 0,
          zoom: 4.5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid longitude', () {
      expect(
        () => calculateMapPointCameraTarget(
          latitude: 0,
          longitude: 181,
          zoom: 4.5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid zoom', () {
      expect(
        () => calculateMapPointCameraTarget(
          latitude: 0,
          longitude: 0,
          zoom: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite screen offsets', () {
      expect(
        () => calculateMapPointCameraTarget(
          latitude: 0,
          longitude: 0,
          zoom: 4.5,
          targetScreenOffset: const Offset(double.infinity, 0),
        ),
        throwsArgumentError,
      );
    });
  });
}
