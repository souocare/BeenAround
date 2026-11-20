import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/presentation/map_overlay_layout.dart';

void main() {
  group('calculateMapOverlayLayout', () {
    test('preserves full-width toolbar without selection', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(844, 390),
        safePadding: EdgeInsets.zero,
        hasSelection: false,
      );

      expect(layout.hasSidePanel, isFalse);
      expect(layout.left, 16);
      expect(layout.right, 16);
      expect(layout.toolbarTop, 12);
    });

    test('reserves space for selected landscape panel', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(844, 390),
        safePadding: EdgeInsets.zero,
        hasSelection: true,
      );

      expect(layout.hasSidePanel, isTrue);

      expect(layout.left, 16);

      // 844 * 0.42 = 354.48.
      // Plus 12 px outer panel margin and 16 px separation.
      expect(layout.right, closeTo(382.48, 0.001));

      final availableWidth = 844 - layout.left - layout.right;

      expect(availableWidth, closeTo(445.52, 0.001));
    });

    test('includes safe areas in horizontal placement', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(844, 390),
        safePadding: const EdgeInsets.fromLTRB(59, 0, 59, 21),
        hasSelection: true,
      );

      expect(layout.left, 75);
      expect(layout.right, closeTo(441.48, 0.001));
    });

    test('preserves portrait horizontal positioning', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(390, 844),
        safePadding: const EdgeInsets.fromLTRB(0, 62, 0, 34),
        hasSelection: true,
      );

      expect(layout.hasSidePanel, isFalse);
      expect(layout.left, 16);
      expect(layout.right, 16);
      expect(layout.toolbarTop, 74);
      expect(layout.resultsTop, 134);
    });

    test('constrains results to landscape viewport height', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(844, 390),
        safePadding: const EdgeInsets.fromLTRB(0, 0, 0, 21),
        hasSelection: true,
      );

      expect(layout.resultsTop, 72);

      // 390 - 72 - 21 - 12 = 285.
      expect(layout.resultsMaxHeight, 285);
    });

    test('accounts for the keyboard without double-counting safe area', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(390, 844),
        safePadding: const EdgeInsets.fromLTRB(0, 62, 0, 34),
        hasSelection: true,
        keyboardInset: 300,
      );

      expect(layout.resultsTop, 134);
      expect(layout.resultsMaxHeight, 398);
    });

    test('limits results height on large screens', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(1440, 900),
        safePadding: EdgeInsets.zero,
        hasSelection: true,
      );

      expect(layout.resultsMaxHeight, 420);
    });

    test('never returns a negative results height', () {
      final layout = calculateMapOverlayLayout(
        viewportSize: const Size(568, 320),
        safePadding: const EdgeInsets.only(top: 20),
        hasSelection: true,
        keyboardInset: 280,
      );

      expect(layout.resultsMaxHeight, 0);
    });

    test('rejects invalid viewport dimensions', () {
      expect(
        () => calculateMapOverlayLayout(
          viewportSize: const Size(0, 600),
          safePadding: EdgeInsets.zero,
          hasSelection: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
