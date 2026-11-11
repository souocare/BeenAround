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
  FakePickerCountriesRepository? countriesRepository,
  FakePickerCityVisitsRepository? cityVisitsRepository,
  FakeTripFormAssociationRepository? associationRepository,
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
}
