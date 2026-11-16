import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/world_map_viewport.dart';

void main() {
  group('calculateWorldMapViewport', () {
    test('uses zoom 1.0 in portrait', () {
      final viewport = calculateWorldMapViewport(width: 390, height: 844);

      expect(viewport.longitude, 0);
      expect(viewport.latitude, 0);
      expect(viewport.zoom, 1.0);
    });

    test('uses zoom 1.0 in landscape', () {
      final viewport = calculateWorldMapViewport(width: 844, height: 390);

      expect(viewport.zoom, 1.0);
    });

    test('uses zoom 1.0 on desktop', () {
      final viewport = calculateWorldMapViewport(width: 1200, height: 800);

      expect(viewport.zoom, 1.0);
    });
  });
}
