import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_layer_visibility.dart';
import 'package:beenaround/features/map/presentation/widgets/map_layer_filter_control.dart';

class _StatefulLayerControlHarness extends StatefulWidget {
  const _StatefulLayerControlHarness();

  @override
  State<_StatefulLayerControlHarness> createState() =>
      _StatefulLayerControlHarnessState();
}

class _StatefulLayerControlHarnessState
    extends State<_StatefulLayerControlHarness> {
  MapLayerVisibility visibility = const MapLayerVisibility();

  @override
  Widget build(BuildContext context) {
    return MapLayerFilterControl(
      visibility: visibility,
      onVisibilityChanged: (nextVisibility) {
        setState(() {
          visibility = nextVisibility;
        });
      },
    );
  }
}

void main() {
  Widget buildControl({
    MapLayerVisibility visibility = const MapLayerVisibility(),
    ValueChanged<MapLayerVisibility>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: MapLayerFilterControl(
              visibility: visibility,
              onVisibilityChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('MapLayerFilterControl', () {
    testWidgets('starts with the popover closed', (tester) async {
      await tester.pumpWidget(buildControl());

      expect(find.byKey(const Key('mapLayersButton')), findsOneWidget);

      expect(find.text('MAP LAYERS'), findsNothing);
    });

    testWidgets('opens the layer popover', (tester) async {
      await tester.pumpWidget(buildControl());

      await tester.tap(find.byKey(const Key('mapLayersButton')));

      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsOneWidget);
      expect(find.text('Countries'), findsOneWidget);
      expect(find.text('Cities'), findsOneWidget);
      expect(find.text('Airports'), findsOneWidget);
      expect(find.text('Flight routes'), findsOneWidget);
    });

    testWidgets('closes when the button is tapped again', (tester) async {
      await tester.pumpWidget(buildControl());

      final button = find.byKey(const Key('mapLayersButton'));

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsNothing);
    });

    testWidgets('reports updated visibility without closing', (tester) async {
      MapLayerVisibility? updatedVisibility;

      await tester.pumpWidget(
        buildControl(
          onChanged: (visibility) {
            updatedVisibility = visibility;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('mapLayersButton')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mapLayerSwitch:Flight routes')));

      await tester.pump();

      expect(updatedVisibility, isNotNull);
      expect(updatedVisibility!.flightRoutes, isFalse);

      // The menu must remain open after changing a switch.
      expect(find.text('MAP LAYERS'), findsOneWidget);
    });

    testWidgets('shows the visibility received from application state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildControl(
          visibility: const MapLayerVisibility(
            countries: false,
            cities: true,
            airports: false,
            flightRoutes: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mapLayersButton')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mapLayerSwitch:Countries')), findsOneWidget);

      expect(
        find.byKey(const Key('mapLayerSwitch:Flight routes')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
    testWidgets('supports successive visibility changes while remaining open', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: _StatefulLayerControlHarness(),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(const Key('mapLayersButton'));

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsOneWidget);

      // Disable Countries.
      await tester.tap(find.byKey(const Key('mapLayerSwitch:Countries')));

      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsOneWidget);

      // Disable Flight routes without closing the panel.
      await tester.tap(find.byKey(const Key('mapLayerSwitch:Flight routes')));

      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsOneWidget);

      final harness = tester.state<_StatefulLayerControlHarnessState>(
        find.byType(_StatefulLayerControlHarness),
      );

      expect(harness.visibility.countries, isFalse);
      expect(harness.visibility.cities, isTrue);
      expect(harness.visibility.airports, isTrue);
      expect(harness.visibility.flightRoutes, isFalse);

      // Close the popover.
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('MAP LAYERS'), findsNothing);

      // Reopen: the previous preferences must be preserved.
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(harness.visibility.countries, isFalse);
      expect(harness.visibility.flightRoutes, isFalse);

      // Re-enable Countries.
      await tester.tap(find.byKey(const Key('mapLayerSwitch:Countries')));

      await tester.pumpAndSettle();

      expect(harness.visibility.countries, isTrue);
      expect(harness.visibility.flightRoutes, isFalse);
    });
  });
}
