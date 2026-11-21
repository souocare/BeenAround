import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_flight_route.dart';
import 'package:beenaround/features/map/presentation/widgets/map_flight_route_panel.dart';

void main() {
  const firstAirport = MapAirportData(
    airportId: 10,
    code: 'LIS',
    name: 'Lisbon Airport',
    countryCode: 'PT',
    latitude: 38.7742,
    longitude: -9.1342,
    departureCount: 2,
    arrivalCount: 1,
    flightCount: 3,
  );

  const secondAirport = MapAirportData(
    airportId: 20,
    code: 'MAD',
    name: 'Madrid Airport',
    countryCode: 'ES',
    latitude: 40.4983,
    longitude: -3.5676,
    departureCount: 1,
    arrivalCount: 2,
    flightCount: 3,
  );

  const route = MapFlightRoute(
    firstAirportId: 10,
    secondAirportId: 20,
    flights: [
      MapFlightRouteFlight(
        flightId: 'F3',
        departureAirportId: 10,
        arrivalAirportId: 20,
        departureOn: '2025-09-08',
        flightNumber: 'TP1234',
      ),
      MapFlightRouteFlight(
        flightId: 'F2',
        departureAirportId: 20,
        arrivalAirportId: 10,
        departureOn: '2024-04-19',
      ),
      MapFlightRouteFlight(
        flightId: 'F1',
        departureAirportId: 10,
        arrivalAirportId: 20,
        departureOn: '2024-04-12',
      ),
    ],
  );

  Widget buildPanel({
    MapFlightRoute selectedRoute = route,
    MapAirportData? first = firstAirport,
    MapAirportData? second = secondAirport,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 700,
          child: MapFlightRoutePanel(
            route: selectedRoute,
            firstAirport: first,
            secondAirport: second,
            onClose: onClose ?? () {},
            panelScrollController: ScrollController(),
            showDragHandle: false,
          ),
        ),
      ),
    );
  }

  group('MapFlightRoutePanel', () {
    testWidgets('shows the route identity', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('LIS ↔ MAD'), findsOneWidget);
      expect(find.text('Lisbon Airport · Madrid Airport'), findsOneWidget);
    });

    testWidgets('shows the total completed flight count', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Completed flights'), findsOneWidget);
    });

    testWidgets('preserves individual flight directions', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('LIS → MAD'), findsNWidgets(2));
      expect(find.text('MAD → LIS'), findsOneWidget);
    });

    testWidgets('shows flight dates and numbers', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('8 Sep 2025'), findsOneWidget);
      expect(find.text('19 Apr 2024'), findsOneWidget);
      expect(find.text('TP1234'), findsOneWidget);
    });

    testWidgets('supports missing airport metadata', (tester) async {
      await tester.pumpWidget(buildPanel(first: null, second: null));

      expect(find.text('Airport 10 ↔ Airport 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('calls onClose when the close button is tapped', (
      tester,
    ) async {
      var closeCount = 0;

      await tester.pumpWidget(buildPanel(onClose: () => closeCount++));

      await tester.tap(find.byKey(const Key('mapFlightRoutePanelClose')));

      expect(closeCount, 1);
    });

    testWidgets('uses one shared scrollable content area', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(
        find.byKey(const Key('mapFlightRoutePanelScrollView')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
