import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_country_focus_padding.dart';
import 'package:beenaround/features/map/map_panel_layout.dart';
import 'package:beenaround/features/map/application/map_camera_focus_frame.dart';

void main() {
  group('calculateCountryFocusPadding', () {
    test('reserves space for the initial bottom panel', () {
      final padding = calculateCountryFocusPadding(
        viewportSize: const Size(390, 844),
        topSafeArea: 62,
      );

      expect(padding.left, 55);
      expect(padding.right, 55);

      // Bottom padding accounts for the panel occupying 42%
      // of the viewport, plus a small geographic margin.
      expect(padding.bottom, closeTo(844 * 0.42 + 24, 0.001));

      expect(padding.top, 127);
    });

    test('reserves space for a landscape side panel', () {
      final padding = calculateCountryFocusPadding(
        viewportSize: const Size(844, 390),
      );

      expect(padding.left, 55);

      // 42% of 844 = 354.48.
      // The panel has an additional right-side margin.
      expect(padding.right, closeTo(844 * 0.42 + 28, 0.001));

      expect(padding.bottom, 55);
    });

    test('uses the bottom panel on narrow viewports', () {
      final padding = calculateCountryFocusPadding(
        viewportSize: const Size(568, 320),
      );

      expect(padding.left, 55);
      expect(padding.right, 55);
      expect(padding.bottom, greaterThan(100));
    });

    test('rejects invalid viewport dimensions', () {
      expect(
        () => calculateCountryFocusPadding(viewportSize: const Size(0, 844)),
        throwsArgumentError,
      );
    });
    test('panel extents are ordered correctly', () {
      expect(
        MapPanelLayout.closedExtent,
        lessThan(MapPanelLayout.compactExtent),
      );

      expect(
        MapPanelLayout.compactExtent,
        lessThan(MapPanelLayout.initialExtent),
      );

      expect(
        MapPanelLayout.initialExtent,
        lessThan(MapPanelLayout.expandedExtent),
      );

      expect(MapPanelLayout.expandedExtent, lessThanOrEqualTo(1.0));
    });
    test('matches shared contextual framing in landscape', () {
      const viewport = Size(1000, 600);
      const topSafeArea = 20.0;

      final countryPadding = calculateCountryFocusPadding(
        viewportSize: viewport,
        topSafeArea: topSafeArea,
      );

      final frame = calculateMapCameraFocusFrame(
        viewportSize: viewport,
        topSafeArea: topSafeArea,
      );

      expect(countryPadding, frame.padding);

      expect(countryPadding.left, 55);
      expect(countryPadding.right, 418);
      expect(countryPadding.top, 75);
      expect(countryPadding.bottom, 55);
    });

    test('matches shared contextual framing in portrait', () {
      const viewport = Size(390, 844);
      const topSafeArea = 62.0;

      final countryPadding = calculateCountryFocusPadding(
        viewportSize: viewport,
        topSafeArea: topSafeArea,
      );

      final frame = calculateMapCameraFocusFrame(
        viewportSize: viewport,
        topSafeArea: topSafeArea,
      );

      expect(countryPadding, frame.padding);
      expect(countryPadding.bottom, closeTo(378.48, 0.001));
    });
  });
}
