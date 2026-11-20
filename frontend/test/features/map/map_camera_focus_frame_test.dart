import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_camera_focus_frame.dart';
import 'package:beenaround/features/map/map_panel_layout.dart';

void main() {
  group('MapPanelLayout', () {
    test('identifies a wide landscape viewport', () {
      expect(
        MapPanelLayout.usesSidePanel(viewportWidth: 1000, viewportHeight: 600),
        isTrue,
      );
    });

    test('does not use a side panel in portrait', () {
      expect(
        MapPanelLayout.usesSidePanel(viewportWidth: 390, viewportHeight: 844),
        isFalse,
      );
    });

    test('does not use a side panel below the breakpoint', () {
      expect(
        MapPanelLayout.usesSidePanel(viewportWidth: 599, viewportHeight: 400),
        isFalse,
      );
    });

    test('clamps the side panel width', () {
      expect(MapPanelLayout.sidePanelWidth(700), 300);
      expect(MapPanelLayout.sidePanelWidth(1000), 390);
      expect(MapPanelLayout.sidePanelWidth(1600), 390);
    });
  });

  group('calculateMapCameraFocusFrame', () {
    test('reserves space for the right-side panel in landscape', () {
      final frame = calculateMapCameraFocusFrame(
        viewportSize: const Size(1000, 600),
        topSafeArea: 0,
      );

      expect(frame.padding.left, 55);
      expect(frame.padding.right, 418);
      expect(frame.padding.top, 55);
      expect(frame.padding.bottom, 55);

      expect(frame.visibleCenter.dx, 318.5);
      expect(frame.viewportCenter.dx, 500);

      expect(frame.targetScreenOffset.dx, -181.5);
      expect(frame.targetScreenOffset.dy, 0);
    });

    test('reserves the bottom panel in portrait', () {
      final frame = calculateMapCameraFocusFrame(
        viewportSize: const Size(390, 844),
        topSafeArea: 0,
      );

      expect(frame.padding.left, 55);
      expect(frame.padding.right, 55);

      expect(frame.padding.top, 65);
      expect(frame.padding.bottom, closeTo(378.48, 0.001));

      expect(frame.targetScreenOffset.dx, 0);
      expect(frame.targetScreenOffset.dy, lessThan(0));
    });

    test('accounts for the top safe area', () {
      final frame = calculateMapCameraFocusFrame(
        viewportSize: const Size(1000, 600),
        topSafeArea: 20,
      );

      expect(frame.padding.top, 75);
      expect(frame.targetScreenOffset.dy, 10);
    });

    test('adapts to different desktop viewport widths', () {
      final smaller = calculateMapCameraFocusFrame(
        viewportSize: const Size(800, 600),
        topSafeArea: 0,
      );

      final larger = calculateMapCameraFocusFrame(
        viewportSize: const Size(1600, 900),
        topSafeArea: 0,
      );

      expect(smaller.padding.right, 364);
      expect(larger.padding.right, 418);

      expect(smaller.targetScreenOffset.dx, lessThan(0));
      expect(larger.targetScreenOffset.dx, lessThan(0));
    });

    test('preserves a valid visible rectangle', () {
      final frame = calculateMapCameraFocusFrame(
        viewportSize: const Size(1000, 600),
        topSafeArea: 0,
      );

      expect(frame.visibleRect.width, greaterThan(0));
      expect(frame.visibleRect.height, greaterThan(0));

      expect(frame.visibleCenter, frame.visibleRect.center);
    });
  });
}
