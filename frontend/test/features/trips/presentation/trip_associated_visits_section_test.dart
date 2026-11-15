import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_associated_visits_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_city_repositories.dart';
import '../fakes/fake_countries_repository.dart';
import '../fakes/fake_trip_association_repository.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';

import 'package:beenaround/features/explore/presentation/widgets/add_destination_sheet.dart';

import '../helpers/contextual_visit_test_helpers.dart';

const tripId = 'trip-1';

class FakeSectionCityRepository extends Fake implements CityRepository {}

class FakeSectionCityVisitsRepository extends Fake
    implements CityVisitsRepository {
  @override
  Future<List<CityVisit>> getCityVisits() async => const [];
}

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
  CityRepository? cityRepository,
  CityVisitsRepository? cityVisitsRepository,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CountriesRepository>.value(
        value: countriesRepository ?? FakeCountriesRepository(),
      ),
      RepositoryProvider<CityRepository>(
        create: (_) => FakeSectionCityRepository(),
      ),
      RepositoryProvider<CityVisitsRepository>(
        create: (_) => FakeSectionCityVisitsRepository(),
      ),
      RepositoryProvider<CityRepository>.value(
        value: cityRepository ?? FakeCityRepository(),
      ),

      RepositoryProvider<CityVisitsRepository>.value(
        value: cityVisitsRepository ?? FakeCityVisitsRepository(),
      ),
    ],
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
    await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

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
  testWidgets('opens contextual country creation from Trip Details', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    // Open the Country Visit Picker.
    final addCountryButton = find.byKey(
      const Key('addTripCountriesVisitButton'),
    );

    await tester.ensureVisible(addCountryButton);
    await tester.pumpAndSettle();

    await tester.tap(addCountryButton);
    await tester.pumpAndSettle();

    expect(find.text('Add country visits'), findsOneWidget);

    // Open the real contextual creation form.
    final createVisitButton = find.byKey(
      const Key('createVisitFromPickerButton'),
    );

    await tester.tap(createVisitButton);
    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsOneWidget);

    expect(find.text('Create country visit'), findsOneWidget);

    // No Trip association is performed by opening the form.
    expect(repository.countryVisits, isEmpty);

    expect(tester.takeException(), isNull);
  });
  testWidgets('canceling contextual creation returns to the country picker', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    // Open the country visit picker.
    final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Add country visits'), findsOneWidget);

    // Open the real creation form.
    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsOneWidget);

    // Cancel creation without persisting a visit.
    final closeButton = find.descendant(
      of: find.byType(AddDestinationSheet),
      matching: find.byTooltip('Close'),
    );

    expect(closeButton, findsOneWidget);

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    // Only the creation form closes.
    expect(find.byType(AddDestinationSheet), findsNothing);

    expect(find.text('Add country visits'), findsOneWidget);

    expect(
      find.byKey(const Key('createVisitFromPickerButton')),
      findsOneWidget,
    );

    // No association was requested.
    expect(repository.addCountryVisitCalls, 0);

    // Now cancel the picker itself.
    await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

    await tester.pumpAndSettle();

    expect(find.text('Add country visits'), findsNothing);

    expect(
      find.text('No country visits associated with this Trip yet.'),
      findsOneWidget,
    );

    expect(repository.countryVisits, isEmpty);
    expect(repository.addCountryVisitCalls, 0);

    expect(tester.takeException(), isNull);
  });

  testWidgets('opens contextual city creation from Trip Details', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('addTripCitiesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Add city visits'), findsOneWidget);

    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsOneWidget);

    expect(find.text('Create city visit'), findsOneWidget);

    expect(repository.cityVisits, isEmpty);
    expect(repository.addCityVisitCalls, 0);

    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'creates a country visit independently and associates it only after picker confirmation',
    (tester) async {
      final associationRepository = FakeTripAssociationRepository();

      final countriesRepository = FakeCountriesRepository();

      // Simulate backend association using the real persisted visit.
      associationRepository.onAddCountryVisit = (tripId, visitId) async {
        expect(tripId, 'trip-1');

        final matchingVisits = countriesRepository.availableVisits
            .where((visit) => visit.id == visitId)
            .toList(growable: false);

        expect(matchingVisits, hasLength(1));

        associationRepository.countryVisits.add(matchingVisits.single);
      };

      await tester.pumpWidget(
        buildTestApp(
          associationRepository,
          countriesRepository: countriesRepository,
        ),
      );

      await tester.pumpAndSettle();

      // ---------------------------------------------------------
      // 1. Initial state.
      // ---------------------------------------------------------

      expect(countriesRepository.availableVisits, isEmpty);

      expect(associationRepository.countryVisits, isEmpty);

      expect(associationRepository.addCountryVisitCalls, 0);

      // ---------------------------------------------------------
      // 2. Open the Country Visit Picker.
      // ---------------------------------------------------------

      final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Add country visits'), findsOneWidget);

      // ---------------------------------------------------------
      // 3. Open contextual creation.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      expect(find.byType(AddDestinationSheet), findsOneWidget);

      expect(find.text('Create country visit'), findsOneWidget);

      // ---------------------------------------------------------
      // 4. Create Portugal visit.
      // ---------------------------------------------------------

      await createContextualCountryVisit(tester);

      // ---------------------------------------------------------
      // 5. Verify independent persistence.
      // ---------------------------------------------------------

      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(countriesRepository.availableVisits, hasLength(1));

      final createdVisit = countriesRepository.availableVisits.single;

      expect(createdVisit.countryCode, 'PT');

      expect(createdVisit.startedOn, DateTime(2024, 6, 1));

      expect(createdVisit.endedOn, DateTime(2024, 8, 1));

      // No Trip association exists yet.
      expect(associationRepository.addCountryVisitCalls, 0);

      expect(associationRepository.countryVisits, isEmpty);

      // ---------------------------------------------------------
      // 6. Verify picker state.
      // ---------------------------------------------------------

      expect(find.byType(AddDestinationSheet), findsNothing);

      expect(find.text('Add country visits'), findsOneWidget);

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);

      expect(find.text('1 visit selected'), findsOneWidget);

      // Creating does not associate automatically.
      expect(associationRepository.addCountryVisitCalls, 0);

      // ---------------------------------------------------------
      // 7. Confirm the picker.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      // ---------------------------------------------------------
      // 8. Verify association.
      // ---------------------------------------------------------

      expect(associationRepository.addCountryVisitCalls, 1);

      expect(associationRepository.countryVisits, hasLength(1));

      expect(associationRepository.countryVisits.single.id, createdVisit.id);

      expect(
        find.byKey(Key('tripCountryVisit-${createdVisit.id}')),
        findsOneWidget,
      );

      // The global historical record still exists.
      expect(countriesRepository.availableVisits, hasLength(1));

      expect(countriesRepository.availableVisits.single.id, createdVisit.id);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'canceling the picker preserves a newly created country visit without association',
    (tester) async {
      final associationRepository = FakeTripAssociationRepository();

      final countriesRepository = FakeCountriesRepository();

      await tester.pumpWidget(
        buildTestApp(
          associationRepository,
          countriesRepository: countriesRepository,
        ),
      );

      await tester.pumpAndSettle();

      // ---------------------------------------------------------
      // 1. Open the picker.
      // ---------------------------------------------------------

      final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // ---------------------------------------------------------
      // 2. Open contextual creation.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      expect(find.byType(AddDestinationSheet), findsOneWidget);

      // ---------------------------------------------------------
      // 3. Persist the visit globally.
      // ---------------------------------------------------------

      await createContextualCountryVisit(tester);

      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(countriesRepository.availableVisits, hasLength(1));

      final createdVisit = countriesRepository.availableVisits.single;

      expect(createdVisit.countryCode, 'PT');

      // ---------------------------------------------------------
      // 4. Verify automatic selection.
      // ---------------------------------------------------------

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);

      expect(find.text('1 visit selected'), findsOneWidget);

      expect(associationRepository.addCountryVisitCalls, 0);

      // ---------------------------------------------------------
      // 5. Cancel the picker.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

      await tester.pumpAndSettle();

      // ---------------------------------------------------------
      // 6. Verify no association was created.
      // ---------------------------------------------------------

      expect(find.text('Add country visits'), findsNothing);

      expect(associationRepository.addCountryVisitCalls, 0);

      expect(associationRepository.countryVisits, isEmpty);

      expect(
        find.text('No country visits associated with this Trip yet.'),
        findsOneWidget,
      );

      // ---------------------------------------------------------
      // 7. Verify the independent visit remains persisted.
      // ---------------------------------------------------------

      expect(countriesRepository.availableVisits, hasLength(1));

      expect(countriesRepository.availableVisits.single.id, createdVisit.id);

      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'creates a city visit and associates it only after picker confirmation',
    (tester) async {
      final associationRepository = FakeTripAssociationRepository();

      final cityRepository = FakeCityRepository();
      final cityVisitsRepository = FakeCityVisitsRepository();

      associationRepository.onAddCityVisit = (tripId, visitId) async {
        expect(tripId, 'trip-1');

        final matchingVisits = cityVisitsRepository.createdVisits
            .where((visit) => visit.id == visitId)
            .toList();

        expect(matchingVisits, hasLength(1));

        associationRepository.cityVisits.add(matchingVisits.single);
      };

      await tester.pumpWidget(
        buildTestApp(
          associationRepository,
          cityRepository: cityRepository,
          cityVisitsRepository: cityVisitsRepository,
        ),
      );

      await tester.pumpAndSettle();

      expect(cityVisitsRepository.createdVisits, isEmpty);
      expect(associationRepository.cityVisits, isEmpty);

      // Open City Visit Picker.
      final addButton = find.byKey(const Key('addTripCitiesVisitButton'));

      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Add city visits'), findsOneWidget);

      // Open contextual City Visit creation.
      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      expect(find.byType(AddDestinationSheet), findsOneWidget);

      // Create Lisbon Visit.
      await createContextualCityVisit(tester);

      // The visit now exists independently.
      expect(cityVisitsRepository.createCalls, 1);
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      final createdVisit = cityVisitsRepository.createdVisits.single;

      expect(createdVisit.cityId, 2267057);
      expect(createdVisit.cityName, 'Lisbon');
      expect(createdVisit.countryCode, 'PT');

      expect(createdVisit.startedOn, DateTime(2024, 6, 1));
      expect(createdVisit.endedOn, DateTime(2024, 8, 1));

      // No Country Visit was implicitly associated.
      expect(cityVisitsRepository.lastCountryVisitId, isNull);
      expect(cityVisitsRepository.lastNewCountryVisit, isNull);

      // No Trip association yet.
      expect(associationRepository.addCityVisitCalls, 0);
      expect(associationRepository.cityVisits, isEmpty);

      // The picker has recovered the persisted visit.
      expect(find.byType(AddDestinationSheet), findsNothing);

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('1 visit selected'), findsOneWidget);

      // Confirm association.
      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(associationRepository.addCityVisitCalls, 1);
      expect(associationRepository.cityVisits, hasLength(1));

      expect(associationRepository.cityVisits.single.id, createdVisit.id);

      expect(
        find.byKey(Key('tripCityVisit-${createdVisit.id}')),
        findsOneWidget,
      );

      // Independent history is preserved.
      expect(cityVisitsRepository.createdVisits, hasLength(1));
      expect(cityVisitsRepository.createCalls, 1);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('canceling the city picker preserves the global city visit', (
    tester,
  ) async {
    final associationRepository = FakeTripAssociationRepository();

    final cityVisitsRepository = FakeCityVisitsRepository();

    await tester.pumpWidget(
      buildTestApp(
        associationRepository,
        cityRepository: FakeCityRepository(),
        cityVisitsRepository: cityVisitsRepository,
      ),
    );

    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('addTripCitiesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    await createContextualCityVisit(tester);

    expect(cityVisitsRepository.createCalls, 1);
    expect(cityVisitsRepository.createdVisits, hasLength(1));

    final createdVisit = cityVisitsRepository.createdVisits.single;

    expect(find.text('NEW'), findsOneWidget);

    // Cancel the picker, not the persisted visit.
    await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

    await tester.pumpAndSettle();

    expect(associationRepository.addCityVisitCalls, 0);
    expect(associationRepository.cityVisits, isEmpty);

    // The global record must still exist.
    expect(cityVisitsRepository.createdVisits, hasLength(1));

    expect(cityVisitsRepository.createdVisits.single.id, createdVisit.id);

    expect(cityVisitsRepository.createCalls, 1);

    expect(
      find.text('No city visits associated with this Trip yet.'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('opens contextual visit creation above the picker on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsOneWidget);

    // The underlying picker remains mounted.
    expect(find.text('Add country visits'), findsOneWidget);

    // Close only the creation form.
    final closeButton = find.descendant(
      of: find.byType(AddDestinationSheet),
      matching: find.byTooltip('Close'),
    );

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsNothing);

    expect(find.text('Add country visits'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
  testWidgets('opens contextual visit creation above the picker on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('addTripCountriesVisitButton'));

    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsOneWidget);

    expect(find.text('Add country visits'), findsOneWidget);

    final closeButton = find.descendant(
      of: find.byType(AddDestinationSheet),
      matching: find.byTooltip('Close'),
    );

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.byType(AddDestinationSheet), findsNothing);

    expect(find.text('Add country visits'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
