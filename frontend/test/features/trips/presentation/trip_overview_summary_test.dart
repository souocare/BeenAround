import 'package:beenaround/app/theme/app_tokens.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_overview_summary.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_trip_association_repository.dart';

CountryVisit countryVisit({required String id, required String countryCode}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: DateTime(2024, 6, 1),
    endedOn: DateTime(2024, 6, 30),
    startedOnPrecision: VisitDatePrecision.day,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit cityVisit({
  required String id,
  required int cityId,
  required String cityName,
  required String countryCode,
  required String countryName,
}) {
  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: DateTime(2024, 6, 1),
    endedOn: DateTime(2024, 6, 30),
    startedOnPrecision: VisitDatePrecision.day,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

// The Overview only reads the number of Flight records.
// Individual Flight fields are deliberately not required.
class FakeOverviewFlight extends Fake implements Flight {}

Widget buildTestApp(
  TripAssociationsCubit cubit, {
  double textScale = 1.0,
  double horizontalPadding = 0,
}) {
  return MaterialApp(
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: Scaffold(
      body: BlocProvider<TripAssociationsCubit>.value(
        value: cubit,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: const TripOverviewSummary(),
        ),
      ),
    ),
  );
}

void expectMetric({required String key, required int value}) {
  final metric = find.byKey(Key(key));

  expect(metric, findsOneWidget);

  expect(
    find.descendant(of: metric, matching: find.text('$value')),
    findsOneWidget,
  );
}

void main() {
  group('TripOverviewSummary', () {
    testWidgets(
      'does not display summary values before associations are loaded',
      (tester) async {
        final repository = FakeTripAssociationRepository();

        final cubit = TripAssociationsCubit(
          repository: repository,
          tripId: 'trip-1',
        );

        addTearDown(cubit.close);

        await tester.pumpWidget(buildTestApp(cubit));

        expect(find.byKey(const Key('tripOverviewSummary')), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows zero counts for a Trip without associated records', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final cubit = TripAssociationsCubit(
        repository: repository,
        tripId: 'trip-1',
      );

      addTearDown(cubit.close);

      await tester.pumpWidget(buildTestApp(cubit));

      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripOverviewSummary')), findsOneWidget);

      expectMetric(key: 'tripOverviewCountries', value: 0);

      expectMetric(key: 'tripOverviewCities', value: 0);

      expectMetric(key: 'tripOverviewFlights', value: 0);

      expect(tester.takeException(), isNull);
    });

    testWidgets('counts unique countries instead of country visits', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        countryVisits: [
          countryVisit(id: 'country-visit-1', countryCode: 'JP'),
          countryVisit(id: 'country-visit-2', countryCode: 'JP'),
          countryVisit(id: 'country-visit-3', countryCode: 'PT'),
        ],
      );

      final cubit = TripAssociationsCubit(
        repository: repository,
        tripId: 'trip-1',
      );

      addTearDown(cubit.close);

      await tester.pumpWidget(buildTestApp(cubit));

      await cubit.load();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCountries', value: 2);

      expectMetric(key: 'tripOverviewCities', value: 0);

      expectMetric(key: 'tripOverviewFlights', value: 0);

      expect(repository.countryVisits, hasLength(3));

      expect(tester.takeException(), isNull);
    });

    testWidgets('counts unique cities instead of city visits', (tester) async {
      final repository = FakeTripAssociationRepository(
        cityVisits: [
          cityVisit(
            id: 'city-visit-1',
            cityId: 2267057,
            cityName: 'Lisbon',
            countryCode: 'PT',
            countryName: 'Portugal',
          ),
          cityVisit(
            id: 'city-visit-2',
            cityId: 2267057,
            cityName: 'Lisbon',
            countryCode: 'PT',
            countryName: 'Portugal',
          ),
          cityVisit(
            id: 'city-visit-3',
            cityId: 3117735,
            cityName: 'Madrid',
            countryCode: 'ES',
            countryName: 'Spain',
          ),
        ],
      );

      final cubit = TripAssociationsCubit(
        repository: repository,
        tripId: 'trip-1',
      );

      addTearDown(cubit.close);

      await tester.pumpWidget(buildTestApp(cubit));

      await cubit.load();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCountries', value: 0);

      expectMetric(key: 'tripOverviewCities', value: 2);

      expectMetric(key: 'tripOverviewFlights', value: 0);

      expect(repository.cityVisits, hasLength(3));

      expect(tester.takeException(), isNull);
    });

    testWidgets('counts associated Flights as individual records', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [
          FakeOverviewFlight(),
          FakeOverviewFlight(),
          FakeOverviewFlight(),
        ],
      );

      final cubit = TripAssociationsCubit(
        repository: repository,
        tripId: 'trip-1',
      );

      addTearDown(cubit.close);

      await tester.pumpWidget(buildTestApp(cubit));

      await cubit.load();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCountries', value: 0);

      expectMetric(key: 'tripOverviewCities', value: 0);

      expectMetric(key: 'tripOverviewFlights', value: 3);

      expect(tester.takeException(), isNull);
    });

    testWidgets('updates summary counts when Trip associations change', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final cubit = TripAssociationsCubit(
        repository: repository,
        tripId: 'trip-1',
      );

      addTearDown(cubit.close);

      await tester.pumpWidget(buildTestApp(cubit));

      await cubit.load();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCountries', value: 0);

      expectMetric(key: 'tripOverviewCities', value: 0);

      expectMetric(key: 'tripOverviewFlights', value: 0);

      // Simulate associations created elsewhere in the UI.
      repository.countryVisits.add(
        countryVisit(id: 'country-visit-1', countryCode: 'JP'),
      );

      repository.cityVisits.add(
        cityVisit(
          id: 'city-visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      );

      repository.flights.add(FakeOverviewFlight());

      await cubit.refresh();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCountries', value: 1);

      expectMetric(key: 'tripOverviewCities', value: 1);

      expectMetric(key: 'tripOverviewFlights', value: 1);

      // Simulate another Country Visit for the same country.
      repository.countryVisits.add(
        countryVisit(id: 'country-visit-2', countryCode: 'JP'),
      );

      await cubit.refresh();
      await tester.pumpAndSettle();

      // Another visit does not mean another unique country.
      expectMetric(key: 'tripOverviewCountries', value: 1);

      // Remove the previously associated City Visit.
      repository.cityVisits.clear();

      await cubit.refresh();
      await tester.pumpAndSettle();

      expectMetric(key: 'tripOverviewCities', value: 0);

      expectMetric(key: 'tripOverviewFlights', value: 1);

      expect(tester.takeException(), isNull);
    });
    for (final width in <double>[320, 390, 768, 1280]) {
      for (final textScale in <double>[1.0, 1.5, 2.0]) {
        testWidgets('renders at ${width.toInt()}px with ${textScale}x text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;

          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final repository = FakeTripAssociationRepository(
            countryVisits: [
              countryVisit(id: 'country-visit-1', countryCode: 'JP'),
            ],
            cityVisits: [
              cityVisit(
                id: 'city-visit-1',
                cityId: 1850147,
                cityName: 'Tokyo',
                countryCode: 'JP',
                countryName: 'Japan',
              ),
            ],
            flights: [FakeOverviewFlight()],
          );

          final cubit = TripAssociationsCubit(
            repository: repository,
            tripId: 'trip-1',
          );

          addTearDown(cubit.close);

          await cubit.load();

          await tester.pumpWidget(
            buildTestApp(
              cubit,
              textScale: textScale,
              horizontalPadding: width < 600 ? AppSpacing.md : AppSpacing.xl,
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byKey(const Key('tripOverviewSummary')), findsOneWidget);

          expectMetric(key: 'tripOverviewCountries', value: 1);

          expectMetric(key: 'tripOverviewCities', value: 1);

          expectMetric(key: 'tripOverviewFlights', value: 1);

          expect(find.text('Countries'), findsOneWidget);
          expect(find.text('Cities'), findsOneWidget);
          expect(find.text('Flights'), findsOneWidget);

          expect(
            tester.takeException(),
            isNull,
            reason:
                'Overview overflow at ${width.toInt()}px '
                'with ${textScale}x text.',
          );
        });
      }
    }
  });
}
