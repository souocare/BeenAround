import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_destination_status.dart';
import 'package:beenaround/features/map/presentation/widgets/map_status_filter.dart';
import 'package:beenaround/features/map/presentation/widgets/map_toolbar.dart';

void main() {
  Widget buildToolbar({
    required double width,
    MapDestinationStatus status = MapDestinationStatus.visited,
    bool isSearchOpen = false,
    bool allowCompactFilter = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MapToolbar(
              selectedStatus: status,
              isSearchOpen: isSearchOpen,
              allowCompactFilter: allowCompactFilter,
              onSearchOpen: () {},
              onSearchClose: () {},
              onSearchChanged: (_) {},
              onStatusSelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('MapToolbar responsive presentation', () {
    testWidgets('uses full filter labels on wide layouts', (tester) async {
      await tester.pumpWidget(buildToolbar(width: 520));

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isFalse);

      expect(find.byKey(const Key('mapStatusFilter')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses compact filter labels on narrow layouts', (tester) async {
      await tester.pumpWidget(buildToolbar(width: 320));

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isTrue);

      expect(find.byKey(const Key('mapSearchControl')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses compact layout immediately below breakpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildToolbar(width: MapToolbar.compactBreakpoint - 1),
      );

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isTrue);
    });

    testWidgets('uses full layout at breakpoint', (tester) async {
      await tester.pumpWidget(
        buildToolbar(width: MapToolbar.compactBreakpoint),
      );

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isFalse);
    });

    testWidgets('keeps search field available in compact mode', (tester) async {
      await tester.pumpWidget(buildToolbar(width: 320, isSearchOpen: true));

      expect(find.byKey(const Key('mapSearchField')), findsOneWidget);

      expect(find.byKey(const Key('mapSearchClose')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports each destination status in compact mode', (
      tester,
    ) async {
      for (final status in MapDestinationStatus.values) {
        await tester.pumpWidget(buildToolbar(width: 320, status: status));

        final filter = tester.widget<MapStatusFilter>(
          find.byType(MapStatusFilter),
        );

        expect(filter.selectedStatus, status);
        expect(filter.compact, isTrue);
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets('preserves full filter labels in portrait mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildToolbar(width: 358, allowCompactFilter: false),
      );

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isFalse);
      expect(tester.takeException(), isNull);
    });
    testWidgets('compacts filter in constrained landscape mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildToolbar(width: 320, allowCompactFilter: true),
      );

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('supports expanded search with full filter label', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildToolbar(width: 358, isSearchOpen: true, allowCompactFilter: false),
      );

      expect(find.byKey(const Key('mapSearchField')), findsOneWidget);

      expect(find.byKey(const Key('mapSearchClose')), findsOneWidget);

      final filter = tester.widget<MapStatusFilter>(
        find.byType(MapStatusFilter),
      );

      expect(filter.compact, isFalse);

      expect(tester.takeException(), isNull);
    });
  });
}
