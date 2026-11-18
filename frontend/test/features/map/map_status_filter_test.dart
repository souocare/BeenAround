import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_destination_status.dart';
import 'package:beenaround/features/map/presentation/widgets/map_status_filter.dart';

void main() {
  Widget buildTestApp({
    MapDestinationStatus selectedStatus = MapDestinationStatus.visited,
    ValueChanged<MapDestinationStatus>? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MapStatusFilter(
            selectedStatus: selectedStatus,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('MapStatusFilter', () {
    testWidgets('shows the currently selected map status', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.byKey(const Key('mapStatusFilter')), findsOneWidget);

      expect(find.textContaining('Visited'), findsOneWidget);
    });

    testWidgets('updates the displayed status', (tester) async {
      await tester.pumpWidget(
        buildTestApp(selectedStatus: MapDestinationStatus.visited),
      );

      expect(find.textContaining('Visited'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(selectedStatus: MapDestinationStatus.wishlist),
      );

      expect(find.textContaining('Wishlist'), findsOneWidget);
    });

    testWidgets('keeps the filter available for all statuses', (tester) async {
      for (final status in MapDestinationStatus.values) {
        await tester.pumpWidget(buildTestApp(selectedStatus: status));

        expect(find.byKey(const Key('mapStatusFilter')), findsOneWidget);
      }
    });
  });
}
