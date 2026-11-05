import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_associated_visits_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_countries_repository.dart';
import '../fakes/fake_trip_association_repository.dart';

const tripId = 'trip-1';

CountryVisit countryVisit() {
  return CountryVisit(
    id: 'country-1',
    countryCode: 'JP',
    startedOn: DateTime(2027, 4, 1),
    endedOn: DateTime(2027, 4, 25),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit cityVisit() {
  return CityVisit(
    id: 'city-1',
    cityId: 1850147,
    cityName: 'Tokyo',
    countryCode: 'JP',
    countryName: 'Japan',
    startedOn: DateTime(2027, 4, 10),
    endedOn: DateTime(2027, 4, 15),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget buildTestApp(
  TripAssociationRepository repository, {
  CountriesRepository? countriesRepository,
}) {
  return RepositoryProvider<CountriesRepository>.value(
    value: countriesRepository ?? FakeCountriesRepository(),
    child: MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) =>
              TripAssociationsCubit(repository: repository, tripId: tripId)
                ..load(),
          child: const SingleChildScrollView(
            child: TripAssociatedVisitsSection(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows empty states when no visits are associated', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(FakeTripAssociationRepository()));

    await tester.pumpAndSettle();

    expect(find.text('Countries'), findsOneWidget);
    expect(find.text('Cities'), findsOneWidget);

    expect(
      find.text('No country visits associated with this Trip yet.'),
      findsOneWidget,
    );

    expect(
      find.text('No city visits associated with this Trip yet.'),
      findsOneWidget,
    );
  });

  testWidgets('shows associated country visits with full country names', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    // Country labels are resolved using the geographical catalog.
    expect(find.text('Japan'), findsOneWidget);

    // ISO codes remain internal identifiers, not primary display labels.
    expect(find.text('JP'), findsNothing);
  });

  testWidgets('shows associated city visits', (tester) async {
    final repository = FakeTripAssociationRepository(cityVisits: [cityVisit()]);

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCityVisit-city-1')), findsOneWidget);

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
  });

  testWidgets('shows both country and city visits', (tester) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
      cityVisits: [cityVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    expect(find.byKey(const Key('tripCityVisit-city-1')), findsOneWidget);
  });
  testWidgets('canceling country removal preserves the association', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final removeButton = find.byKey(
      const Key('removeTripCountryVisit-country-1'),
    );

    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('removeTripVisitDialog')), findsOneWidget);

    expect(
      find.textContaining('remain in your travel history'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cancelRemoveTripVisitButton')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    expect(repository.countryVisits, hasLength(1));
  });
  testWidgets('removing a country association updates the Trip', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final removeButton = find.byKey(
      const Key('removeTripCountryVisit-country-1'),
    );

    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmRemoveTripVisitButton')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsNothing);

    expect(
      find.text('No country visits associated with this Trip yet.'),
      findsOneWidget,
    );

    expect(repository.countryVisits, isEmpty);
  });
  testWidgets('removing a city association updates the Trip', (tester) async {
    final repository = FakeTripAssociationRepository(cityVisits: [cityVisit()]);

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final removeButton = find.byKey(const Key('removeTripCityVisit-city-1'));

    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tokyo'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirmRemoveTripVisitButton')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCityVisit-city-1')), findsNothing);

    expect(
      find.text('No city visits associated with this Trip yet.'),
      findsOneWidget,
    );

    expect(repository.cityVisits, isEmpty);
  });
  testWidgets('removing a country does not affect city associations', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
      cityVisits: [cityVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final removeButton = find.byKey(
      const Key('removeTripCountryVisit-country-1'),
    );

    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmRemoveTripVisitButton')));

    await tester.pumpAndSettle();

    expect(repository.countryVisits, isEmpty);
    expect(repository.cityVisits, hasLength(1));

    expect(find.byKey(const Key('tripCityVisit-city-1')), findsOneWidget);
  });
  testWidgets('displays full country names', (tester) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsOneWidget);
  });
  testWidgets('loads the country catalog only once', (tester) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    final countriesRepository = FakeCountriesRepository();

    await tester.pumpWidget(
      buildTestApp(repository, countriesRepository: countriesRepository),
    );

    await tester.pumpAndSettle();

    expect(countriesRepository.catalogLoadCount, 1);

    // Refresh associations, triggering another BlocBuilder update.
    final cubit = tester
        .element(find.byType(TripAssociatedVisitsSection))
        .read<TripAssociationsCubit>();

    await cubit.refresh();

    await tester.pumpAndSettle();

    expect(countriesRepository.catalogLoadCount, 1);
  });
  testWidgets('uses ISO code when country is missing from catalog', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    final countriesRepository = FakeCountriesRepository(countries: const []);

    await tester.pumpWidget(
      buildTestApp(repository, countriesRepository: countriesRepository),
    );

    await tester.pumpAndSettle();

    expect(find.text('JP'), findsOneWidget);
  });
  testWidgets('adding an existing country visit updates the Trip', (
    tester,
  ) async {
    final visit = countryVisit();

    final associationRepository = FakeTripAssociationRepository();

    final countriesRepository = FakeCountriesRepository();

    // This visit exists in the user's global travel history.
    countriesRepository.availableVisits.add(visit);

    // Simulate a successful association on the backend.
    associationRepository.onAddCountryVisit = (tripId, visitId) async {
      expect(tripId, 'trip-1');
      expect(visitId, visit.id);

      associationRepository.countryVisits.add(visit);
    };

    await tester.pumpWidget(
      buildTestApp(
        associationRepository,
        countriesRepository: countriesRepository,
      ),
    );

    await tester.pumpAndSettle();

    // Initially, no visits are associated with the Trip.
    expect(
      find.text('No country visits associated with this Trip yet.'),
      findsOneWidget,
    );

    // Open the existing visits picker.
    final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // The picker loads the user's existing country visits.
    expect(countriesRepository.countryVisitLoadCount, 1);

    expect(find.byKey(Key('tripVisitOption-${visit.id}')), findsOneWidget);

    // Select the existing visit.
    await tester.tap(find.byKey(Key('tripVisitOption-${visit.id}')));

    await tester.pumpAndSettle();

    // The Cubit associates the visit and refreshes its data.
    expect(associationRepository.addCountryVisitCalls, 1);

    expect(associationRepository.countryVisits, hasLength(1));

    // The associated visit is now visible in Trip Details.
    expect(find.byKey(Key('tripCountryVisit-${visit.id}')), findsOneWidget);

    expect(find.text('Japan'), findsOneWidget);

    // The original historical visit still exists.
    expect(countriesRepository.availableVisits, hasLength(1));

    expect(countriesRepository.availableVisits.single.id, visit.id);
  });
}
