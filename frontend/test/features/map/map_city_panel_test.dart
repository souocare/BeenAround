import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_city_panel_projection.dart';
import 'package:beenaround/features/map/presentation/widgets/map_city_panel.dart';

const visitedCity = MapCityPanelData(
  cityId: 10,
  name: 'Lisbon',
  countryCode: 'PT',
  countryName: 'Portugal',
  visitCount: 3,
  residenceCount: 1,
  isWishlisted: true,
);

const wishlistCity = MapCityPanelData(
  cityId: 20,
  name: 'Tokyo',
  countryCode: 'JP',
  countryName: 'Japan',
  visitCount: 0,
  residenceCount: 0,
  isWishlisted: true,
);

const unrecordedCity = MapCityPanelData(
  cityId: 30,
  name: 'Oslo',
  countryCode: 'NO',
  countryName: 'Norway',
  visitCount: 0,
  residenceCount: 0,
  isWishlisted: false,
);

Widget buildTestPanel({required MapCityPanelData data, VoidCallback? onClose}) {
  return MaterialApp(
    home: Scaffold(
      body: MapCityPanel(data: data, onClose: onClose ?? () {}),
    ),
  );
}

void main() {
  group('MapCityPanel', () {
    testWidgets('shows city identity and country', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: visitedCity));

      expect(find.text('Lisbon'), findsOneWidget);
      expect(find.text('Portugal'), findsOneWidget);
    });

    testWidgets('shows all applicable statuses', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: visitedCity));

      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('Lived'), findsOneWidget);
      expect(find.text('Wishlist'), findsOneWidget);

      expect(find.text('Not visited'), findsNothing);
    });

    testWidgets('shows visit and residence statistics', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: visitedCity));

      expect(find.byKey(const Key('mapCityPanelStatistics')), findsOneWidget);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('Residences'), findsOneWidget);
    });

    testWidgets('shows travel history summary', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: visitedCity));

      expect(find.text('Travel history'), findsOneWidget);
      expect(find.text('3 recorded visits'), findsOneWidget);
      expect(find.text('1 residence period'), findsOneWidget);
    });

    testWidgets('shows wishlist-only information', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: wishlistCity));

      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Wishlist'), findsOneWidget);

      expect(find.byKey(const Key('mapCityPanelWishlistInfo')), findsOneWidget);

      expect(find.text('Saved to wishlist'), findsOneWidget);

      expect(find.byKey(const Key('mapCityPanelStatistics')), findsNothing);

      expect(find.byKey(const Key('mapCityPanelEmpty')), findsNothing);
    });

    testWidgets('shows empty state for a city without history', (tester) async {
      await tester.pumpWidget(buildTestPanel(data: unrecordedCity));

      expect(find.text('Oslo'), findsOneWidget);
      expect(find.text('Not visited'), findsOneWidget);

      expect(find.byKey(const Key('mapCityPanelEmpty')), findsOneWidget);

      expect(find.text('No travel history recorded'), findsOneWidget);

      expect(find.byKey(const Key('mapCityPanelStatistics')), findsNothing);
    });

    testWidgets('closes through the close button', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        buildTestPanel(
          data: visitedCity,
          onClose: () {
            closed = true;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('mapCityPanelClose')));

      expect(closed, isTrue);
    });

    testWidgets('does not overflow on narrow screens', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestPanel(data: visitedCity));

      expect(find.byKey(const Key('mapCityPanelStatuses')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports long city names', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const city = MapCityPanelData(
        cityId: 100,
        name: 'Very Long Geographic City Destination Name',
        countryCode: 'PT',
        countryName: 'Portugal',
        visitCount: 1,
        residenceCount: 0,
        isWishlisted: false,
      );

      await tester.pumpWidget(buildTestPanel(data: city));

      expect(
        find.text('Very Long Geographic City Destination Name'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
