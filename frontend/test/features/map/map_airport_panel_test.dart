import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';
import 'package:beenaround/features/map/presentation/widgets/map_airport_panel.dart';

const lisbonDestination = MapSearchDestination(
  type: MapSearchDestinationType.airport,
  id: 'airport:10',
  title: 'Humberto Delgado Airport',
  subtitle: 'LIS',
  countryCode: 'PT',
  latitude: 38.7742,
  longitude: -9.1342,
  airportCode: 'LIS',
  airportLocation: 'Lisbon, Portugal',
);

const unusedDestination = MapSearchDestination(
  type: MapSearchDestinationType.airport,
  id: 'airport:20',
  title: 'Leonardo da Vinci Airport',
  subtitle: 'FCO',
  countryCode: 'IT',
  latitude: 41.8003,
  longitude: 12.2389,
  airportCode: 'FCO',
  airportLocation: 'Rome, Italy',
);

const lisbonAirport = MapAirportData(
  airportId: 10,
  code: 'LIS',
  name: 'Humberto Delgado Airport',
  countryCode: 'PT',
  latitude: 38.7742,
  longitude: -9.1342,
  departureCount: 5,
  arrivalCount: 3,
  flightCount: 8,
);

Widget buildTestPanel({
  required MapSearchDestination destination,
  MapAirportData? airport,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MapAirportPanel(
        destination: destination,
        airport: airport,
        onClose: onClose ?? () {},
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Use a predictable portrait viewport for bottom-sheet tests.
  });

  group('MapAirportPanel', () {
    testWidgets('shows airport identity and location', (tester) async {
      await tester.pumpWidget(
        buildTestPanel(destination: lisbonDestination, airport: lisbonAirport),
      );

      expect(find.text('LIS'), findsOneWidget);
      expect(find.text('Humberto Delgado Airport'), findsOneWidget);
      expect(find.text('Lisbon, Portugal'), findsOneWidget);
    });

    testWidgets('shows completed-flight statistics', (tester) async {
      await tester.pumpWidget(
        buildTestPanel(destination: lisbonDestination, airport: lisbonAirport),
      );

      expect(
        find.byKey(const Key('mapAirportPanelStatistics')),
        findsOneWidget,
      );

      expect(find.text('Used in flight history'), findsOneWidget);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      expect(find.text('Flights'), findsOneWidget);
      expect(find.text('Departures'), findsOneWidget);
      expect(find.text('Arrivals'), findsOneWidget);
    });

    testWidgets('shows empty state for an unused airport', (tester) async {
      await tester.pumpWidget(buildTestPanel(destination: unusedDestination));

      expect(find.text('FCO'), findsOneWidget);
      expect(find.text('Rome, Italy'), findsOneWidget);

      expect(find.text('Not in flight history'), findsOneWidget);

      expect(find.text('No flights recorded'), findsOneWidget);

      expect(find.byKey(const Key('mapAirportPanelStatistics')), findsNothing);
    });

    testWidgets('closes through the close button', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        buildTestPanel(
          destination: lisbonDestination,
          airport: lisbonAirport,
          onClose: () {
            closed = true;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('mapAirportPanelClose')));

      expect(closed, isTrue);
    });

    testWidgets('does not display flight statistics without history', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestPanel(destination: unusedDestination));

      expect(find.byKey(const Key('mapAirportPanelEmpty')), findsOneWidget);

      expect(find.byKey(const Key('mapAirportPanelStatistics')), findsNothing);
    });

    testWidgets('supports an airport without location metadata', (
      tester,
    ) async {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:30',
        title: 'Unknown Airport',
        subtitle: '',
        airportCode: 'ABC',
      );

      await tester.pumpWidget(buildTestPanel(destination: destination));

      expect(find.text('ABC'), findsOneWidget);
      expect(find.text('Unknown Airport'), findsOneWidget);
      expect(find.byKey(const Key('mapAirportPanelLocation')), findsNothing);
    });
    testWidgets('status badge does not overflow on narrow screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestPanel(destination: lisbonDestination, airport: lisbonAirport),
      );

      expect(find.text('Used in flight history'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
