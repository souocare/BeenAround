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
import 'package:beenaround/core/models/visit_date_precision.dart';

const tripId = 'trip-1';

CountryVisit countryVisit({
  String id = 'country-1',
  String countryCode = 'JP',
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: startedOn ?? DateTime(2027, 4, 1),
    endedOn: endedOn ?? DateTime(2027, 4, 25),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit cityVisit({
  String id = 'city-1',
  int cityId = 1850147,
  String cityName = 'Tokyo',
  String countryCode = 'JP',
  String countryName = 'Japan',
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: startedOn ?? DateTime(2027, 4, 10),
    endedOn: endedOn ?? DateTime(2027, 4, 15),
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

    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

    expect(find.byKey(const Key('tripCitiesEmptyState')), findsOneWidget);

    expect(find.text('No countries added'), findsOneWidget);

    expect(find.text('No cities added'), findsOneWidget);

    expect(
      find.byKey(const Key('addTripCountriesVisitButton')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('addTripCitiesVisitButton')), findsOneWidget);

    expect(tester.takeException(), isNull);
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
    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

    expect(
      find.byKey(const Key('addTripCountriesVisitButton')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

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
    expect(find.byKey(const Key('tripCitiesEmptyState')), findsOneWidget);

    expect(find.byKey(const Key('addTripCitiesVisitButton')), findsOneWidget);

    expect(find.byKey(const Key('tripCitiesEmptyState')), findsOneWidget);

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
    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

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

    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

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

      expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

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

    expect(find.byKey(const Key('tripCitiesEmptyState')), findsOneWidget);

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
  testWidgets('displays repeated country visits as separate cards', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [
        countryVisit(
          id: 'japan-2023',
          startedOn: DateTime(2023, 9, 3),
          endedOn: DateTime(2023, 9, 14),
        ),
        countryVisit(
          id: 'japan-2025',
          startedOn: DateTime(2025, 5, 12),
          endedOn: DateTime(2025, 5, 26),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final firstVisit = find.byKey(const Key('tripCountryVisit-japan-2023'));

    final secondVisit = find.byKey(const Key('tripCountryVisit-japan-2025'));

    expect(firstVisit, findsOneWidget);
    expect(secondVisit, findsOneWidget);

    expect(
      find.descendant(of: firstVisit, matching: find.text('Japan')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: secondVisit, matching: find.text('Japan')),
      findsOneWidget,
    );

    // Each independently persisted visit has its own removal action.
    expect(
      find.byKey(const Key('removeTripCountryVisit-japan-2023')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('removeTripCountryVisit-japan-2025')),
      findsOneWidget,
    );

    expect(repository.countryVisits, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('city visit card displays city, country and visit dates', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      cityVisits: [
        cityVisit(
          id: 'tokyo-2025',
          startedOn: DateTime(2025, 5, 13),
          endedOn: DateTime(2025, 5, 17),
        ),
      ],
    );
    final visit = repository.cityVisits.single;

    expect(visit.startedOn?.year, 2025);
    expect(visit.endedOn?.year, 2025);

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final cityCard = find.byKey(const Key('tripCityVisit-tokyo-2025'));

    expect(cityCard, findsOneWidget);

    expect(
      find.descendant(of: cityCard, matching: find.text('Tokyo')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: cityCard, matching: find.text('Japan')),
      findsOneWidget,
    );

    final dates = find.descendant(
      of: cityCard,
      matching: find.textContaining('May 13'),
    );

    expect(dates, findsOneWidget);

    expect(
      find.descendant(of: cityCard, matching: find.textContaining('May 17')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cityCard, matching: find.textContaining('2025')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('removeTripCityVisit-tokyo-2025')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('displays repeated city visits independently', (tester) async {
    final repository = FakeTripAssociationRepository(
      cityVisits: [
        cityVisit(
          id: 'tokyo-2023',
          startedOn: DateTime(2023, 4, 1),
          endedOn: DateTime(2023, 4, 8),
        ),
        cityVisit(
          id: 'tokyo-2025',
          startedOn: DateTime(2025, 5, 13),
          endedOn: DateTime(2025, 5, 17),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final firstVisit = find.byKey(const Key('tripCityVisit-tokyo-2023'));

    final secondVisit = find.byKey(const Key('tripCityVisit-tokyo-2025'));

    expect(firstVisit, findsOneWidget);
    expect(secondVisit, findsOneWidget);

    expect(
      find.descendant(of: firstVisit, matching: find.text('Tokyo')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: secondVisit, matching: find.text('Tokyo')),
      findsOneWidget,
    );

    expect(repository.cityVisits, hasLength(2));
    expect(
      find.descendant(of: firstVisit, matching: find.textContaining('2023')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: secondVisit, matching: find.textContaining('2025')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('visit cards render without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = FakeTripAssociationRepository(
        countryVisits: [countryVisit(id: 'country-mobile')],
        cityVisits: [cityVisit(id: 'city-mobile')],
      );

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripCountryVisit-country-mobile')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('tripCityVisit-city-mobile')),
        findsOneWidget,
      );

      // Catch any Flutter layout exceptions, including RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('displays month precision without inventing exact days', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [
        CountryVisit(
          id: 'japan-month-precision',
          countryCode: 'JP',
          startedOn: DateTime(2025, 5, 1),
          endedOn: DateTime(2025, 6, 1),
          startedOnPrecision: VisitDatePrecision.month,
          endedOnPrecision: VisitDatePrecision.month,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final card = find.byKey(
      const Key('tripCountryVisit-japan-month-precision'),
    );

    expect(card, findsOneWidget);

    expect(
      find.descendant(of: card, matching: find.text('May 2025 – June 2025')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('shows one add action per empty visit section', (tester) async {
    final repository = FakeTripAssociationRepository();

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('addTripCountriesVisitButton')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('addTripCitiesVisitButton')), findsOneWidget);

    final countryAction = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('addTripCountriesVisitButton')),
    );

    final cityAction = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('addTripCitiesVisitButton')),
    );

    expect(countryAction.onPressed, isNotNull);
    expect(cityAction.onPressed, isNotNull);

    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shows header add actions instead of empty states when visits exist',
    (tester) async {
      final repository = FakeTripAssociationRepository(
        countryVisits: [countryVisit()],
        cityVisits: [cityVisit()],
      );

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      // Both sections display existing records.
      expect(
        find.byKey(const Key('tripCountryVisit-country-1')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('tripCityVisit-city-1')), findsOneWidget);

      // Empty states are no longer displayed.
      expect(find.byKey(const Key('tripCountriesEmptyState')), findsNothing);

      expect(find.byKey(const Key('tripCitiesEmptyState')), findsNothing);

      // Each section retains exactly one Add action.
      expect(
        find.byKey(const Key('addTripCountriesVisitButton')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('addTripCitiesVisitButton')), findsOneWidget);

      final countryButton = tester.widget<TextButton>(
        find.byKey(const Key('addTripCountriesVisitButton')),
      );

      final cityButton = tester.widget<TextButton>(
        find.byKey(const Key('addTripCitiesVisitButton')),
      );

      expect(countryButton.onPressed, isNotNull);
      expect(cityButton.onPressed, isNotNull);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('shows country empty state independently of city associations', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(cityVisits: [cityVisit()]);

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountriesEmptyState')), findsOneWidget);

    expect(find.byKey(const Key('tripCitiesEmptyState')), findsNothing);

    expect(find.byKey(const Key('tripCityVisit-city-1')), findsOneWidget);

    expect(
      find.byKey(const Key('addTripCountriesVisitButton')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('shows city empty state independently of country associations', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCountriesEmptyState')), findsNothing);

    expect(find.byKey(const Key('tripCitiesEmptyState')), findsOneWidget);

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    expect(find.byKey(const Key('addTripCitiesVisitButton')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'mutation failure preserves associated visits and restores actions',
    (tester) async {
      final repository = FakeTripAssociationRepository(
        countryVisits: [countryVisit()],
      );

      repository.onAddCountryVisit = (tripId, visitId) async {
        throw StateError('Simulated association failure.');
      };

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      final existingVisit = find.byKey(const Key('tripCountryVisit-country-1'));

      expect(existingVisit, findsOneWidget);

      final sectionContext = tester.element(
        find.byType(TripAssociatedVisitsSection),
      );

      final cubit = sectionContext.read<TripAssociationsCubit>();

      // Trigger the same Cubit operation used by the association flow.
      await cubit.addCountryVisit(visitId: 'another-country-visit');

      await tester.pumpAndSettle();

      // The failed operation does not remove existing associations.
      expect(
        find.byKey(const Key('tripCountryVisit-country-1')),
        findsOneWidget,
      );

      expect(repository.countryVisits.length, 1);

      expect(cubit.state.hasMutationError, isTrue);
      expect(cubit.state.isMutating, isFalse);

      // The error is visible to the user.
      final errorBanner = find.byKey(const Key('tripAssociationMutationError'));

      expect(errorBanner, findsOneWidget);

      expect(
        find.descendant(
          of: errorBanner,
          matching: find.text('Unable to update Trip associations.'),
        ),
        findsOneWidget,
      );

      // The user can refresh after an error.
      expect(
        find.descendant(
          of: errorBanner,
          matching: find.widgetWithText(TextButton, 'Refresh'),
        ),
        findsOneWidget,
      );

      // The Add action is available again.
      final addButton = tester.widget<TextButton>(
        find.byKey(const Key('addTripCountriesVisitButton')),
      );

      expect(addButton.onPressed, isNotNull);

      // The existing visit can still be removed.
      final removeButton = tester.widget<IconButton>(
        find.byKey(const Key('removeTripCountryVisit-country-1')),
      );

      expect(removeButton.onPressed, isNotNull);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('refresh clears a previous association mutation error', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(
      countryVisits: [countryVisit()],
    );

    repository.onAddCountryVisit = (tripId, visitId) async {
      throw StateError('Simulated association failure.');
    };

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    final cubit = tester
        .element(find.byType(TripAssociatedVisitsSection))
        .read<TripAssociationsCubit>();

    await cubit.addCountryVisit(visitId: 'another-country-visit');

    await tester.pumpAndSettle();

    final errorBanner = find.byKey(const Key('tripAssociationMutationError'));

    expect(errorBanner, findsOneWidget);

    final refreshButton = find.descendant(
      of: errorBanner,
      matching: find.widgetWithText(TextButton, 'Refresh'),
    );

    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    expect(cubit.state.hasLoadError, isFalse);

    // Refresh reloads records, but does not clear mutationError
    // in the current Cubit implementation.
    expect(cubit.state.hasMutationError, isFalse);

    expect(find.byKey(const Key('tripAssociationMutationError')), findsNothing);

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    expect(find.byKey(const Key('tripCountryVisit-country-1')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
