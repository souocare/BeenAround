import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/application/trip_visit_suggestions.dart';
import 'package:beenaround/features/trips/domain/trip_date_compatibility.dart';
import 'package:beenaround/features/trips/presentation/widgets/inline_trip_visit_suggestions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CountryVisit countryVisit(String id) {
  return CountryVisit(
    id: id,
    countryCode: 'LK',
    startedOn: DateTime(2025, 9, 10),
    endedOn: DateTime(2025, 9, 24),
    startedOnPrecision: VisitDatePrecision.day,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

CityVisit cityVisit(String id) {
  return CityVisit(
    id: id,
    cityId: 123,
    cityName: 'Colombo',
    countryCode: 'LK',
    countryName: 'Sri Lanka',
    startedOn: DateTime(2025, 9, 10),
    endedOn: DateTime(2025, 9, 12),
    startedOnPrecision: VisitDatePrecision.day,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

Widget buildTestApp({
  List<TripVisitSuggestion<CountryVisit>> countrySuggestions = const [],
  List<TripVisitSuggestion<CityVisit>> citySuggestions = const [],
  ValueChanged<CountryVisit>? onCountrySelected,
  ValueChanged<CityVisit>? onCitySelected,
  bool enabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: InlineTripVisitSuggestions(
          countrySuggestions: countrySuggestions,
          citySuggestions: citySuggestions,
          countryNamesByCode: const {'LK': 'Sri Lanka'},
          onCountrySelected: onCountrySelected ?? (_) {},
          onCitySelected: onCitySelected ?? (_) {},
          enabled: enabled,
        ),
      ),
    ),
  );
}

void main() {
  group('Inline Trip Visit Suggestions', () {
    testWidgets('does not render when there are no suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.byKey(const Key('inlineTripVisitSuggestions')), findsNothing);
    });

    testWidgets('shows compatible country visits', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
        ),
      );

      expect(find.text('SUGGESTED VISITS'), findsOneWidget);
      expect(find.text('Sri Lanka'), findsOneWidget);
      expect(find.text('Dates overlap'), findsOneWidget);

      expect(
        find.byKey(const Key('addSuggestedCountryVisit-country-1')),
        findsOneWidget,
      );
    });

    testWidgets('shows compatible city visits', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          citySuggestions: [
            TripVisitSuggestion(
              visit: cityVisit('city-1'),
              compatibility: TripDateCompatibility.possible,
            ),
          ],
        ),
      );

      expect(find.text('Colombo'), findsOneWidget);
      expect(find.text('Sri Lanka'), findsOneWidget);
      expect(find.text('Possible date match'), findsOneWidget);
    });

    testWidgets('selecting a country reports the existing visit', (
      tester,
    ) async {
      CountryVisit? selected;

      await tester.pumpWidget(
        buildTestApp(
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          onCountrySelected: (visit) {
            selected = visit;
          },
        ),
      );

      expect(selected, isNull);

      await tester.tap(
        find.byKey(const Key('addSuggestedCountryVisit-country-1')),
      );

      expect(selected?.id, 'country-1');
      expect(selected?.countryCode, 'LK');
    });

    testWidgets('selecting a city reports the existing visit', (tester) async {
      CityVisit? selected;

      await tester.pumpWidget(
        buildTestApp(
          citySuggestions: [
            TripVisitSuggestion(
              visit: cityVisit('city-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          onCitySelected: (visit) {
            selected = visit;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('addSuggestedCityVisit-city-1')));

      expect(selected?.id, 'city-1');
      expect(selected?.cityName, 'Colombo');
    });

    testWidgets('does not select visits automatically', (tester) async {
      var countrySelections = 0;
      var citySelections = 0;

      await tester.pumpWidget(
        buildTestApp(
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          citySuggestions: [
            TripVisitSuggestion(
              visit: cityVisit('city-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          onCountrySelected: (_) => countrySelections++,
          onCitySelected: (_) => citySelections++,
        ),
      );

      await tester.pumpAndSettle();

      expect(countrySelections, 0);
      expect(citySelections, 0);
    });

    testWidgets('disables selection while submitting', (tester) async {
      var selections = 0;

      await tester.pumpWidget(
        buildTestApp(
          enabled: false,
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          onCountrySelected: (_) => selections++,
        ),
      );

      final button = tester.widget<TextButton>(
        find.byKey(const Key('addSuggestedCountryVisit-country-1')),
      );

      expect(button.onPressed, isNull);
      expect(selections, 0);
    });

    testWidgets('supports country and city suggestions together', (
      tester,
    ) async {
      final selectedIds = <String>[];

      await tester.pumpWidget(
        buildTestApp(
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          citySuggestions: [
            TripVisitSuggestion(
              visit: cityVisit('city-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
          onCountrySelected: (visit) => selectedIds.add(visit.id),
          onCitySelected: (visit) => selectedIds.add(visit.id),
        ),
      );

      await tester.tap(
        find.byKey(const Key('addSuggestedCountryVisit-country-1')),
      );

      await tester.tap(find.byKey(const Key('addSuggestedCityVisit-city-1')));

      expect(selectedIds, ['country-1', 'city-1']);
    });

    testWidgets('updates displayed suggestions when data changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          countrySuggestions: [
            TripVisitSuggestion(
              visit: countryVisit('country-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
        ),
      );

      expect(find.text('Sri Lanka'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(
          citySuggestions: [
            TripVisitSuggestion(
              visit: cityVisit('city-1'),
              compatibility: TripDateCompatibility.match,
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('suggestedCountryVisit-country-1')),
        findsNothing,
      );

      expect(find.text('Colombo'), findsOneWidget);
    });
  });
}
