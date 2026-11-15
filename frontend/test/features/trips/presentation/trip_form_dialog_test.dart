import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_form_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/explore/presentation/widgets/add_destination_sheet.dart';

import '../fakes/fake_countries_repository.dart' as shared_fakes;
import '../fakes/fake_city_repositories.dart';

import '../helpers/contextual_visit_test_helpers.dart';
import 'trip_visit_picker_dialog_test.dart'
    show
        FakePickerCountriesRepository,
        FakePickerCityVisitsRepository,
        countryVisit,
        cityVisit;

class FakeTripFormRepository implements TripRepository {
  int createCalls = 0;
  int updateCalls = 0;

  TripInput? lastInput;
  String? lastUpdatedId;

  @override
  Future<Trip> createTrip({required TripInput input}) async {
    createCalls++;
    lastInput = input;

    return _trip(
      id: 'created-trip',
      name: input.name,
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
    );
  }

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required TripInput input,
  }) async {
    updateCalls++;
    lastUpdatedId = tripId;
    lastInput = input;

    return _trip(
      id: tripId,
      name: input.name,
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
    );
  }

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<List<Trip>> getTripsForCountry({required String countryCode}) {
    throw UnimplementedError('Country Trips are not exercised by this test.');
  }

  @override
  Future<List<Trip>> getTripsForCity({required int cityId}) {
    throw UnimplementedError('City Trips are not exercised by this test.');
  }

  @override
  Future<Trip> getTrip({required String tripId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip({required String tripId}) {
    throw UnimplementedError();
  }
}

class FakeTripFormAssociationRepository extends Fake
    implements TripAssociationRepository {
  final addedCountries = <String>[];
  final addedCities = <String>[];

  final attemptedCountries = <String>[];
  final attemptedCities = <String>[];

  bool failNextCityAssociation = false;

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    attemptedCountries.add(visitId);

    addedCountries.add(visitId);
  }

  @override
  Future<void> addCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    attemptedCities.add(visitId);

    if (failNextCityAssociation) {
      failNextCityAssociation = false;

      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Unable to associate city visit.',
        statusCode: 500,
      );
    }

    addedCities.add(visitId);
  }
}

Trip _trip({
  required String id,
  required String name,
  String? description,
  PartialVisitDate? startedOn,
  PartialVisitDate? endedOn,
}) {
  return Trip(
    id: id,
    name: name,
    description: description,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget buildTestApp(
  TripRepository repository, {
  Trip? existingTrip,
  CountriesRepository? countriesRepository,
  CityVisitsRepository? cityVisitsRepository,
  FakeTripFormAssociationRepository? associationRepository,
  CityRepository? cityRepository,
  ValueChanged<bool>? onResult,
}) {
  final fakeCountriesRepository =
      countriesRepository ?? FakePickerCountriesRepository();

  final fakeCityVisitsRepository =
      cityVisitsRepository ?? FakePickerCityVisitsRepository();

  final fakeAssociationRepository =
      associationRepository ?? FakeTripFormAssociationRepository();

  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<TripRepository>.value(value: repository),
      RepositoryProvider<CountriesRepository>.value(
        value: fakeCountriesRepository,
      ),
      RepositoryProvider<CityVisitsRepository>.value(
        value: fakeCityVisitsRepository,
      ),
      RepositoryProvider<CityRepository>.value(
        value: cityRepository ?? FakeCityRepository(),
      ),
      RepositoryProvider<TripAssociationRepository>.value(
        value: fakeAssociationRepository,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showTripFormDialog(
                    context: context,
                    trip: existingTrip,
                  );

                  onResult?.call(result);
                },
                child: const Text('Open Form'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> tapVisibleTripFormButton(
  WidgetTester tester,
  Finder button,
) async {
  final formScrollView = find.descendant(
    of: find.byType(TripFormDialog),
    matching: find.byType(SingleChildScrollView),
  );

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  var buttonCenter = tester.getCenter(button);

  // ensureVisible() can leave the button outside the test viewport
  // when the form is displayed inside a desktop dialog.
  if (buttonCenter.dy >= viewportHeight - 24) {
    await tester.drag(
      formScrollView.first,
      Offset(0, -(buttonCenter.dy - viewportHeight + 150)),
    );

    await tester.pumpAndSettle();

    buttonCenter = tester.getCenter(button);
  }

  expect(
    buttonCenter.dy,
    lessThan(viewportHeight),
    reason: 'The Trip form button must be inside the test viewport.',
  );

  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> tapSaveTrip(WidgetTester tester) async {
  await tapVisibleTripFormButton(
    tester,
    find.byKey(const Key('saveTripButton')),
  );
}

Future<void> tapCancelTrip(WidgetTester tester) async {
  final button = find.widgetWithText(TextButton, 'Cancel');

  final formScrollView = find.descendant(
    of: find.byType(TripFormDialog),
    matching: find.byType(SingleChildScrollView),
  );

  await tester.dragUntilVisible(
    button,
    formScrollView.first,
    const Offset(0, -150),
  );

  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> selectTripFormVisit(
  WidgetTester tester, {
  required String addButtonKey,
  required String visitOptionKey,
}) async {
  await tapVisibleTripFormButton(tester, find.byKey(Key(addButtonKey)));

  // The picker must open before selecting a visit.
  final visitOption = find.byKey(Key(visitOptionKey));

  expect(
    visitOption,
    findsOneWidget,
    reason: 'The Trip visit picker should display the requested visit.',
  );

  await tester.ensureVisible(visitOption);
  await tester.pumpAndSettle();

  await tester.tap(visitOption);
  await tester.pumpAndSettle();

  final confirmButton = find.byKey(const Key('confirmTripVisitPickerButton'));

  expect(confirmButton, findsOneWidget);

  await tester.ensureVisible(confirmButton);
  await tester.pumpAndSettle();

  await tester.tap(confirmButton);
  await tester.pumpAndSettle();
}

Future<void> selectTripDate(
  WidgetTester tester, {
  required bool isStart,
}) async {
  final field = find.byKey(
    Key(isStart ? 'tripStartDateField' : 'tripEndDateField'),
  );

  await tapVisibleTripFormButton(tester, field);

  // Select exact-day precision.
  await tester.tap(find.byKey(const Key('datePrecision_day')));

  await tester.pumpAndSettle();

  // Widget tests run with the Material date picker by default.
  expect(find.byType(DatePickerDialog), findsOneWidget);

  // Confirm its initially selected date.
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens Create Trip form', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    expect(find.text('New Trip'), findsOneWidget);
    expect(find.byKey(const Key('tripNameField')), findsOneWidget);
    expect(find.byKey(const Key('tripDescriptionField')), findsOneWidget);
    expect(find.byKey(const Key('saveTripButton')), findsOneWidget);
  });

  testWidgets('creates a Trip without dates', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan 2027',
    );

    await tapSaveTrip(tester);

    expect(repository.createCalls, 1);
    expect(repository.lastInput?.name, 'Japan 2027');

    expect(repository.lastInput?.startedOn, isNull);
    expect(repository.lastInput?.endedOn, isNull);

    expect(find.text('New Trip'), findsNothing);
  });

  testWidgets('rejects an empty Trip name', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tapSaveTrip(tester);

    expect(find.text('Enter a Trip name.'), findsOneWidget);

    expect(repository.createCalls, 0);
  });

  testWidgets('opens Edit Trip with existing values', (tester) async {
    final repository = FakeTripFormRepository();

    final existingTrip = _trip(
      id: 'trip-1',
      name: 'Japan 2027',
      description: 'Spring holiday',
    );

    await tester.pumpWidget(
      buildTestApp(repository, existingTrip: existingTrip),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Trip'), findsOneWidget);

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('tripNameField')),
    );

    expect(nameField.controller?.text, 'Japan 2027');

    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const Key('tripDescriptionField')),
    );

    expect(descriptionField.controller?.text, 'Spring holiday');
  });

  testWidgets('updates an existing Trip', (tester) async {
    final repository = FakeTripFormRepository();

    final existingTrip = _trip(id: 'trip-1', name: 'Japan 2027');

    await tester.pumpWidget(
      buildTestApp(repository, existingTrip: existingTrip),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan & Korea 2027',
    );

    await tapSaveTrip(tester);

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 1);

    expect(repository.lastUpdatedId, 'trip-1');
    expect(repository.lastInput?.name, 'Japan & Korea 2027');
  });

  testWidgets('cancel does not persist changes', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tapCancelTrip(tester);

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 0);

    expect(find.text('New Trip'), findsNothing);
  });
  testWidgets('editing a Trip does not require destination repositories', (
    tester,
  ) async {
    final repository = FakeTripFormRepository();

    final existingTrip = _trip(id: 'trip-1', name: 'Japan 2027');

    await tester.pumpWidget(
      RepositoryProvider<TripRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () =>
                    showTripFormDialog(context: context, trip: existingTrip),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('creates a Trip with selected country and city visits', (
    tester,
  ) async {
    final repository = FakeTripFormRepository();

    final countriesRepository = FakePickerCountriesRepository();
    final cityVisitsRepository = FakePickerCityVisitsRepository();

    final associationRepository = FakeTripFormAssociationRepository();

    countriesRepository.visits.add(countryVisit(id: 'country-visit-1'));

    cityVisitsRepository.visits.add(cityVisit(id: 'city-visit-1'));

    await tester.pumpWidget(
      buildTestApp(
        repository,
        countriesRepository: countriesRepository,
        cityVisitsRepository: cityVisitsRepository,
        associationRepository: associationRepository,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan 2027',
    );

    // Select a country visit.
    await selectTripFormVisit(
      tester,
      addButtonKey: 'tripFormAddCountriesButton',
      visitOptionKey: 'tripVisitOption-country-visit-1',
    );

    // Select a city visit.
    await selectTripFormVisit(
      tester,
      addButtonKey: 'tripFormAddCitiesButton',
      visitOptionKey: 'tripVisitOption-city-visit-1',
    );

    // No persistence should happen before Create Trip.
    expect(repository.createCalls, 0);
    expect(associationRepository.addedCountries, isEmpty);
    expect(associationRepository.addedCities, isEmpty);

    await tapSaveTrip(tester);

    expect(repository.createCalls, 1);

    expect(associationRepository.addedCountries, ['country-visit-1']);

    expect(associationRepository.addedCities, ['city-visit-1']);

    expect(find.text('New Trip'), findsNothing);
  });
  testWidgets('retrying failed associations does not recreate the Trip', (
    tester,
  ) async {
    final repository = FakeTripFormRepository();

    final countriesRepository = FakePickerCountriesRepository();
    final cityVisitsRepository = FakePickerCityVisitsRepository();

    final associationRepository = FakeTripFormAssociationRepository()
      ..failNextCityAssociation = true;

    countriesRepository.visits.add(countryVisit(id: 'country-visit-1'));

    cityVisitsRepository.visits.add(cityVisit(id: 'city-visit-1'));

    bool? formResult;

    await tester.pumpWidget(
      buildTestApp(
        repository,
        countriesRepository: countriesRepository,
        cityVisitsRepository: cityVisitsRepository,
        associationRepository: associationRepository,
        onResult: (value) => formResult = value,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan 2027',
    );

    await selectTripFormVisit(
      tester,
      addButtonKey: 'tripFormAddCountriesButton',
      visitOptionKey: 'tripVisitOption-country-visit-1',
    );

    await selectTripFormVisit(
      tester,
      addButtonKey: 'tripFormAddCitiesButton',
      visitOptionKey: 'tripVisitOption-city-visit-1',
    );

    await tapSaveTrip(tester);

    expect(repository.createCalls, 1);

    expect(find.byKey(const Key('tripPartialFailureSection')), findsOneWidget);

    expect(associationRepository.addedCountries, ['country-visit-1']);

    expect(associationRepository.addedCities, isEmpty);

    expect(formResult, isNull);

    await tester.tap(find.byKey(const Key('retryTripAssociationsButton')));

    await tester.pumpAndSettle();

    // The Trip must never be recreated.
    expect(repository.createCalls, 1);

    // Country association must not be repeated.
    expect(associationRepository.attemptedCountries, ['country-visit-1']);

    // City association failed once and succeeded on retry.
    expect(associationRepository.attemptedCities, [
      'city-visit-1',
      'city-visit-1',
    ]);

    expect(associationRepository.addedCities, ['city-visit-1']);

    expect(formResult, isTrue);
    expect(find.text('New Trip'), findsNothing);
  });
  testWidgets('Finish after partial failure preserves the created Trip', (
    tester,
  ) async {
    final repository = FakeTripFormRepository();

    final cityVisitsRepository = FakePickerCityVisitsRepository();

    final associationRepository = FakeTripFormAssociationRepository()
      ..failNextCityAssociation = true;

    cityVisitsRepository.visits.add(cityVisit(id: 'city-visit-1'));

    bool? formResult;

    await tester.pumpWidget(
      buildTestApp(
        repository,
        cityVisitsRepository: cityVisitsRepository,
        associationRepository: associationRepository,
        onResult: (value) => formResult = value,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan 2027',
    );

    await selectTripFormVisit(
      tester,
      addButtonKey: 'tripFormAddCitiesButton',
      visitOptionKey: 'tripVisitOption-city-visit-1',
    );

    await tapSaveTrip(tester);

    // The Trip exists, but the association failed.
    expect(repository.createCalls, 1);

    expect(find.byKey(const Key('tripPartialFailureSection')), findsOneWidget);

    expect(associationRepository.addedCities, isEmpty);

    // Finish without retrying the failed association.
    await tester.tap(find.byKey(const Key('finishPartiallyCreatedTripButton')));

    await tester.pumpAndSettle();

    // The caller must be informed that the Trip was created.
    expect(formResult, isTrue);

    // No duplicate Trip and no unexpected retry.
    expect(repository.createCalls, 1);

    expect(associationRepository.attemptedCities, ['city-visit-1']);

    expect(find.byType(TripFormDialog), findsNothing);
  });
  testWidgets(
    'suggests existing visits only after both Trip dates are selected',
    (tester) async {
      final today = DateTime.now();

      final repository = FakeTripFormRepository();

      final countriesRepository = FakePickerCountriesRepository(
        visits: [
          CountryVisit(
            id: 'suggested-country-1',
            countryCode: 'JP',
            startedOn: DateTime(today.year, today.month, today.day),
            endedOn: DateTime(today.year, today.month, today.day),
            startedOnPrecision: VisitDatePrecision.day,
            endedOnPrecision: VisitDatePrecision.day,
            createdAt: today,
            updatedAt: today,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(repository, countriesRepository: countriesRepository),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inlineTripVisitSuggestions')), findsNothing);

      await selectTripDate(tester, isStart: true);

      expect(find.byKey(const Key('inlineTripVisitSuggestions')), findsNothing);

      await selectTripDate(tester, isStart: false);

      expect(
        find.byKey(const Key('inlineTripVisitSuggestions')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('addSuggestedCountryVisit-suggested-country-1')),
        findsOneWidget,
      );

      // Merely displaying suggestions must not create a Trip.
      expect(repository.createCalls, 0);
    },
  );
  testWidgets(
    'selecting a suggested country adds it to the form without persisting',
    (tester) async {
      final today = DateTime.now();

      final repository = FakeTripFormRepository();
      final associationRepository = FakeTripFormAssociationRepository();

      final countriesRepository = FakePickerCountriesRepository(
        visits: [
          CountryVisit(
            id: 'suggested-country-1',
            countryCode: 'JP',
            startedOn: DateTime(today.year, today.month, today.day),
            endedOn: DateTime(today.year, today.month, today.day),
            startedOnPrecision: VisitDatePrecision.day,
            endedOnPrecision: VisitDatePrecision.day,
            createdAt: today,
            updatedAt: today,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          repository,
          countriesRepository: countriesRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Japan 2026',
      );

      await selectTripDate(tester, isStart: true);
      await selectTripDate(tester, isStart: false);

      final suggestionButton = find.byKey(
        const Key('addSuggestedCountryVisit-suggested-country-1'),
      );

      expect(suggestionButton, findsOneWidget);

      await tapVisibleTripFormButton(tester, suggestionButton);

      // Selected visits should no longer be suggested.
      expect(suggestionButton, findsNothing);

      // The existing visit is now selected in the form.
      expect(
        find.byKey(const Key('selectedCountryVisit-suggested-country-1')),
        findsOneWidget,
      );

      // No Trip or association was persisted by selecting a suggestion.
      expect(repository.createCalls, 0);
      expect(associationRepository.addedCountries, isEmpty);
      expect(associationRepository.addedCities, isEmpty);

      await tapSaveTrip(tester);

      expect(repository.createCalls, 1);

      expect(associationRepository.addedCountries, ['suggested-country-1']);

      expect(associationRepository.addedCities, isEmpty);
    },
  );
  testWidgets(
    'cancelling after selecting a suggestion does not persist anything',
    (tester) async {
      final today = DateTime.now();

      final repository = FakeTripFormRepository();
      final associationRepository = FakeTripFormAssociationRepository();

      final countriesRepository = FakePickerCountriesRepository(
        visits: [
          CountryVisit(
            id: 'suggested-country-1',
            countryCode: 'JP',
            startedOn: DateTime(today.year, today.month, today.day),
            endedOn: DateTime(today.year, today.month, today.day),
            startedOnPrecision: VisitDatePrecision.day,
            endedOnPrecision: VisitDatePrecision.day,
            createdAt: today,
            updatedAt: today,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          repository,
          countriesRepository: countriesRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await selectTripDate(tester, isStart: true);
      await selectTripDate(tester, isStart: false);

      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('addSuggestedCountryVisit-suggested-country-1')),
      );

      await tapCancelTrip(tester);

      expect(repository.createCalls, 0);
      expect(associationRepository.addedCountries, isEmpty);
      expect(associationRepository.addedCities, isEmpty);

      expect(find.text('New Trip'), findsNothing);
    },
  );
  testWidgets('clearing a Trip date hides existing visit suggestions', (
    tester,
  ) async {
    final today = DateTime.now();

    final repository = FakeTripFormRepository();

    final countriesRepository = FakePickerCountriesRepository(
      visits: [
        CountryVisit(
          id: 'suggested-country-1',
          countryCode: 'JP',
          startedOn: DateTime(today.year, today.month, today.day),
          endedOn: DateTime(today.year, today.month, today.day),
          startedOnPrecision: VisitDatePrecision.day,
          endedOnPrecision: VisitDatePrecision.day,
          createdAt: today,
          updatedAt: today,
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(repository, countriesRepository: countriesRepository),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await selectTripDate(tester, isStart: true);
    await selectTripDate(tester, isStart: false);

    expect(find.byKey(const Key('inlineTripVisitSuggestions')), findsOneWidget);

    await tapVisibleTripFormButton(
      tester,
      find.byKey(const Key('clearTripEndDate')),
    );

    expect(find.byKey(const Key('inlineTripVisitSuggestions')), findsNothing);

    expect(repository.createCalls, 0);
  });
  testWidgets(
    'creates a country visit during Trip creation and associates it only after saving',
    (tester) async {
      final tripRepository = FakeTripFormRepository();

      final countriesRepository = shared_fakes.FakeCountriesRepository();

      final cityVisitsRepository = FakePickerCityVisitsRepository();

      final associationRepository = FakeTripFormAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          tripRepository,
          countriesRepository: countriesRepository,
          cityVisitsRepository: cityVisitsRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Portugal 2024',
      );

      // ---------------------------------------------------------
      // 1. Open Country Visit Picker.
      // ---------------------------------------------------------

      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('tripFormAddCountriesButton')),
      );

      expect(find.text('Add country visits'), findsOneWidget);

      // ---------------------------------------------------------
      // 2. Open contextual creation form.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      expect(find.byType(AddDestinationSheet), findsOneWidget);

      // ---------------------------------------------------------
      // 3. Create independent country visit.
      // ---------------------------------------------------------

      await createContextualCountryVisit(tester);

      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(countriesRepository.availableVisits, hasLength(1));

      final createdVisit = countriesRepository.availableVisits.single;

      expect(createdVisit.countryCode, 'PT');

      // Neither the Trip nor its association exists yet.
      expect(tripRepository.createCalls, 0);
      expect(associationRepository.addedCountries, isEmpty);
      expect(associationRepository.attemptedCountries, isEmpty);

      // ---------------------------------------------------------
      // 4. Verify picker state.
      // ---------------------------------------------------------

      expect(find.byType(AddDestinationSheet), findsNothing);

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('1 visit selected'), findsOneWidget);

      // ---------------------------------------------------------
      // 5. Confirm picker.
      // ---------------------------------------------------------

      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      // Confirming the picker must not persist the Trip.
      expect(tripRepository.createCalls, 0);

      // And must not create associations.
      expect(associationRepository.addedCountries, isEmpty);
      expect(associationRepository.attemptedCountries, isEmpty);

      // ---------------------------------------------------------
      // 6. Save Trip.
      // ---------------------------------------------------------

      await tapSaveTrip(tester);

      expect(tripRepository.createCalls, 1);

      expect(tripRepository.lastInput?.name, 'Portugal 2024');

      // The newly created visit is now associated.
      expect(associationRepository.addedCountries, [createdVisit.id]);

      expect(associationRepository.attemptedCountries, [createdVisit.id]);

      // The global record was created exactly once.
      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(countriesRepository.availableVisits, hasLength(1));

      expect(countriesRepository.availableVisits.single.id, createdVisit.id);

      expect(find.text('New Trip'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('canceling Trip creation preserves newly created global visits', (
    tester,
  ) async {
    final tripRepository = FakeTripFormRepository();

    final countriesRepository = shared_fakes.FakeCountriesRepository();

    final associationRepository = FakeTripFormAssociationRepository();

    await tester.pumpWidget(
      buildTestApp(
        tripRepository,
        countriesRepository: countriesRepository,
        associationRepository: associationRepository,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Portugal 2024',
    );

    // Open country picker.
    await tapVisibleTripFormButton(
      tester,
      find.byKey(const Key('tripFormAddCountriesButton')),
    );

    // Open contextual creation.
    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    // Persist visit globally.
    await createContextualCountryVisit(tester);

    expect(countriesRepository.availableVisits, hasLength(1));

    final createdVisit = countriesRepository.availableVisits.single;

    // Confirm picker.
    await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

    await tester.pumpAndSettle();

    expect(tripRepository.createCalls, 0);
    expect(associationRepository.addedCountries, isEmpty);

    // Cancel the entire Trip form.
    await tapCancelTrip(tester);

    // Trip creation was canceled.
    expect(tripRepository.createCalls, 0);

    // No association was created.
    expect(associationRepository.addedCountries, isEmpty);
    expect(associationRepository.attemptedCountries, isEmpty);

    // But the independent visit survives.
    expect(countriesRepository.availableVisits, hasLength(1));

    expect(countriesRepository.availableVisits.single.id, createdVisit.id);

    expect(countriesRepository.createCountryVisitCalls, 1);

    expect(find.text('New Trip'), findsNothing);

    expect(tester.takeException(), isNull);
  });
  testWidgets('canceling the visit picker does not discard the created visit', (
    tester,
  ) async {
    final tripRepository = FakeTripFormRepository();

    final countriesRepository = shared_fakes.FakeCountriesRepository();

    final associationRepository = FakeTripFormAssociationRepository();

    await tester.pumpWidget(
      buildTestApp(
        tripRepository,
        countriesRepository: countriesRepository,
        associationRepository: associationRepository,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    // Open picker.
    await tapVisibleTripFormButton(
      tester,
      find.byKey(const Key('tripFormAddCountriesButton')),
    );

    // Open contextual form.
    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    // Create a real visit through the form.
    await createContextualCountryVisit(tester);

    expect(countriesRepository.availableVisits, hasLength(1));

    final createdVisit = countriesRepository.availableVisits.single;

    expect(find.text('NEW'), findsOneWidget);

    // Cancel picker instead of confirming selection.
    await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

    await tester.pumpAndSettle();

    // Trip form is still open.
    expect(find.text('New Trip'), findsOneWidget);

    // The global visit survives.
    expect(countriesRepository.availableVisits, hasLength(1));

    expect(countriesRepository.availableVisits.single.id, createdVisit.id);

    // No Trip has been created.
    expect(tripRepository.createCalls, 0);

    // No association has been requested.
    expect(associationRepository.addedCountries, isEmpty);
    expect(associationRepository.attemptedCountries, isEmpty);

    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reopening the picker shows a previously created visit without NEW badge',
    (tester) async {
      final tripRepository = FakeTripFormRepository();

      final countriesRepository = shared_fakes.FakeCountriesRepository();

      await tester.pumpWidget(
        buildTestApp(tripRepository, countriesRepository: countriesRepository),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      final addCountriesButton = find.byKey(
        const Key('tripFormAddCountriesButton'),
      );

      await tapVisibleTripFormButton(tester, addCountriesButton);

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      await createContextualCountryVisit(tester);

      final createdVisit = countriesRepository.availableVisits.single;

      expect(find.text('NEW'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

      await tester.pumpAndSettle();

      // Reopen the picker from the same Trip form.
      await tapVisibleTripFormButton(tester, addCountriesButton);

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      // NEW is session-specific, not persisted metadata.
      expect(find.text('NEW'), findsNothing);

      // Canceling the previous picker did not commit its selection.
      expect(find.text('0 visits selected'), findsOneWidget);

      // The visit remains globally available.
      expect(countriesRepository.availableVisits, hasLength(1));

      expect(tripRepository.createCalls, 0);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('contextual creation preserves an existing Trip form selection', (
    tester,
  ) async {
    final tripRepository = FakeTripFormRepository();

    final countriesRepository = shared_fakes.FakeCountriesRepository();

    final associationRepository = FakeTripFormAssociationRepository();

    // An existing independent visit.
    final existingVisit = countryVisit(id: 'existing-country-visit');

    countriesRepository.availableVisits.add(existingVisit);

    await tester.pumpWidget(
      buildTestApp(
        tripRepository,
        countriesRepository: countriesRepository,
        associationRepository: associationRepository,
      ),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan and Portugal',
    );

    await tapVisibleTripFormButton(
      tester,
      find.byKey(const Key('tripFormAddCountriesButton')),
    );

    // Select an existing visit.
    await tester.tap(
      find.byKey(const Key('tripVisitOption-existing-country-visit')),
    );

    await tester.pumpAndSettle();

    expect(find.text('1 visit selected'), findsOneWidget);

    // Create another independent visit.
    await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

    await tester.pumpAndSettle();

    await createContextualCountryVisit(tester);

    expect(countriesRepository.availableVisits, hasLength(2));

    final createdVisit = countriesRepository.availableVisits.last;

    expect(find.text('2 visits selected'), findsOneWidget);

    // Confirm both selections.
    await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

    await tester.pumpAndSettle();

    expect(associationRepository.addedCountries, isEmpty);

    // Associations happen only when the Trip is saved.
    await tapSaveTrip(tester);

    expect(tripRepository.createCalls, 1);

    expect(
      associationRepository.addedCountries,
      containsAll([existingVisit.id, createdVisit.id]),
    );

    expect(associationRepository.addedCountries, hasLength(2));

    expect(countriesRepository.createCountryVisitCalls, 1);

    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'creates a city visit during Trip creation and associates it only after saving',
    (tester) async {
      final tripRepository = FakeTripFormRepository();

      final cityRepository = FakeCityRepository();
      final cityVisitsRepository = FakeCityVisitsRepository();

      final associationRepository = FakeTripFormAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          tripRepository,
          cityRepository: cityRepository,
          cityVisitsRepository: cityVisitsRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Portugal 2024',
      );

      // Open City Visit Picker.
      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('tripFormAddCitiesButton')),
      );

      expect(find.text('Add city visits'), findsOneWidget);

      // Open contextual City creation.
      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      expect(find.byType(AddDestinationSheet), findsOneWidget);

      // Create Lisbon Visit.
      await createContextualCityVisit(tester);

      expect(cityVisitsRepository.createCalls, 1);
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      final createdVisit = cityVisitsRepository.createdVisits.single;

      expect(createdVisit.cityId, 2267057);
      expect(createdVisit.countryCode, 'PT');

      // No implicit Country Visit.
      expect(cityVisitsRepository.lastCountryVisitId, isNull);
      expect(cityVisitsRepository.lastNewCountryVisit, isNull);

      // Trip has not been created.
      expect(tripRepository.createCalls, 0);

      // No association before picker confirmation.
      expect(associationRepository.addedCities, isEmpty);
      expect(associationRepository.attemptedCities, isEmpty);

      expect(
        find.byKey(Key('tripVisitOption-${createdVisit.id}')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('1 visit selected'), findsOneWidget);

      // Confirm selection.
      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      // Still no Trip or association.
      expect(tripRepository.createCalls, 0);
      expect(associationRepository.addedCities, isEmpty);
      expect(associationRepository.attemptedCities, isEmpty);

      // Persist Trip.
      await tapSaveTrip(tester);

      expect(tripRepository.createCalls, 1);

      // Association is now persisted.
      expect(associationRepository.addedCities, [createdVisit.id]);

      expect(associationRepository.attemptedCities, [createdVisit.id]);

      // City Visit was not recreated.
      expect(cityVisitsRepository.createCalls, 1);
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      expect(find.text('New Trip'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'canceling Trip creation preserves an independently created city visit',
    (tester) async {
      final tripRepository = FakeTripFormRepository();

      final cityVisitsRepository = FakeCityVisitsRepository();

      final associationRepository = FakeTripFormAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          tripRepository,
          cityRepository: FakeCityRepository(),
          cityVisitsRepository: cityVisitsRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Portugal 2024',
      );

      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('tripFormAddCitiesButton')),
      );

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      await createContextualCityVisit(tester);

      expect(cityVisitsRepository.createdVisits, hasLength(1));

      final createdVisit = cityVisitsRepository.createdVisits.single;

      // Confirm the picker selection.
      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(tripRepository.createCalls, 0);
      expect(associationRepository.addedCities, isEmpty);

      // Cancel the whole Trip form.
      await tapCancelTrip(tester);

      expect(tripRepository.createCalls, 0);

      expect(associationRepository.addedCities, isEmpty);
      expect(associationRepository.attemptedCities, isEmpty);

      // The City Visit remains independent and persisted.
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      expect(cityVisitsRepository.createdVisits.single.id, createdVisit.id);

      expect(cityVisitsRepository.createCalls, 1);

      expect(find.text('New Trip'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'creates country and city visits independently before saving the Trip',
    (tester) async {
      final tripRepository = FakeTripFormRepository();

      final countriesRepository = shared_fakes.FakeCountriesRepository();

      final cityRepository = FakeCityRepository();
      final cityVisitsRepository = FakeCityVisitsRepository();

      final associationRepository = FakeTripFormAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          tripRepository,
          countriesRepository: countriesRepository,
          cityRepository: cityRepository,
          cityVisitsRepository: cityVisitsRepository,
          associationRepository: associationRepository,
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Portugal 2024',
      );

      // ---------------------------------------------------------
      // Create Country Visit.
      // ---------------------------------------------------------

      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('tripFormAddCountriesButton')),
      );

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      await createContextualCountryVisit(tester);

      final countryVisit = countriesRepository.availableVisits.single;

      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(countriesRepository.createCountryVisitCalls, 1);

      expect(associationRepository.addedCountries, isEmpty);

      // ---------------------------------------------------------
      // Create City Visit.
      // ---------------------------------------------------------

      await tapVisibleTripFormButton(
        tester,
        find.byKey(const Key('tripFormAddCitiesButton')),
      );

      await tester.tap(find.byKey(const Key('createVisitFromPickerButton')));

      await tester.pumpAndSettle();

      await createContextualCityVisit(tester);

      final cityVisit = cityVisitsRepository.createdVisits.single;

      await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(cityVisitsRepository.createCalls, 1);

      // The records exist globally.
      expect(countriesRepository.availableVisits, hasLength(1));
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      // But the Trip still does not exist.
      expect(tripRepository.createCalls, 0);

      // And no associations were persisted.
      expect(associationRepository.addedCountries, isEmpty);
      expect(associationRepository.addedCities, isEmpty);

      // ---------------------------------------------------------
      // Save Trip.
      // ---------------------------------------------------------

      await tapSaveTrip(tester);

      expect(tripRepository.createCalls, 1);

      expect(associationRepository.addedCountries, [countryVisit.id]);

      expect(associationRepository.addedCities, [cityVisit.id]);

      // Nothing was duplicated.
      expect(countriesRepository.createCountryVisitCalls, 1);
      expect(cityVisitsRepository.createCalls, 1);

      expect(countriesRepository.availableVisits, hasLength(1));
      expect(cityVisitsRepository.createdVisits, hasLength(1));

      expect(tester.takeException(), isNull);
    },
  );
}
