import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// Finders
// -----------------------------------------------------------------------------

Finder get addDestinationButton => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == 'Add Destination',
);

// -----------------------------------------------------------------------------
// Fake repositories
// -----------------------------------------------------------------------------

class FakeCountriesRepository implements CountriesRepository {
  int createCalls = 0;
  String? lastCreatedCountryCode;

  final List<CountryVisit> createdVisits = [];

  @override
  Future<List<Country>> getCountries() async => const [
    Country(
      code: 'PT',
      name: 'Portugal',
      alpha3Code: 'PRT',
      continent: 'Europe',
    ),
    Country(code: 'ES', name: 'Spain', alpha3Code: 'ESP', continent: 'Europe'),
    Country(code: 'FR', name: 'France', alpha3Code: 'FRA', continent: 'Europe'),
  ];

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    return List.unmodifiable(createdVisits);
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) async {
    createCalls++;
    lastCreatedCountryCode = countryCode;

    final visit = CountryVisit(
      id: 'visit-$createCalls',
      countryCode: countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      createdAt: DateTime(2026, 10, 21),
      updatedAt: DateTime(2026, 10, 21),
    );

    createdVisits.add(visit);

    return visit;
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError(
      'Country visit updates are not used by this test.',
    );
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError(
      'Country visit deletion is not used by this test.',
    );
  }
}

class FakeCityRepository implements CityRepository {
  int searchCalls = 0;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    int limit = 20,
    int offset = 0,
    CitySort sort = CitySort.population,
  }) async {
    searchCalls++;

    const cities = [
      City(
        id: 2267057,
        name: 'Lisbon',
        asciiName: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        latitude: 38.7167,
        longitude: -9.1333,
        population: 517802,
        featureCode: 'PPLC',
      ),
      City(
        id: 3117735,
        name: 'Madrid',
        asciiName: 'Madrid',
        countryCode: 'ES',
        countryName: 'Spain',
        latitude: 40.4165,
        longitude: -3.7026,
        population: 3255944,
        featureCode: 'PPLC',
      ),
    ];

    final normalizedQuery = query?.trim().toLowerCase() ?? '';

    final matches = cities
        .where((city) {
          final matchesName =
              normalizedQuery.isEmpty ||
              city.name.toLowerCase().contains(normalizedQuery);

          final matchesCountry =
              countryCode == null ||
              city.countryCode == countryCode.toUpperCase();

          return matchesName && matchesCountry;
        })
        .toList(growable: false);

    return CitySearchResult(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    return const [
      CountryCityCount(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityCount: 1,
      ),
      CountryCityCount(countryCode: 'ES', countryName: 'Spain', cityCount: 1),
    ];
  }
}

class FakeCityVisitsRepository implements CityVisitsRepository {
  int createCalls = 0;
  int? lastCreatedCityId;

  DateTime? lastStartedOn;
  DateTime? lastEndedOn;

  final List<CityVisit> createdVisits = [];

  @override
  Future<List<CityVisit>> getCityVisits() async {
    return List.unmodifiable(createdVisits);
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) async {
    createCalls++;
    lastCreatedCityId = cityId;
    lastStartedOn = startedOn;
    lastEndedOn = endedOn;

    final visit = CityVisit(
      id: 'city-visit-$createCalls',
      cityId: cityId,
      cityName: cityId == 2267057 ? 'Lisbon' : 'Madrid',
      countryCode: cityId == 2267057 ? 'PT' : 'ES',
      countryName: cityId == 2267057 ? 'Portugal' : 'Spain',
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      createdAt: DateTime(2026, 10, 24),
      updatedAt: DateTime(2026, 10, 24),
    );

    createdVisits.add(visit);

    return visit;
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

// -----------------------------------------------------------------------------
// Test helpers
// -----------------------------------------------------------------------------

Future<void> selectVisitMonth(
  WidgetTester tester, {
  required String field,
  required int year,
  required int month,
}) async {
  await tester.ensureVisible(find.text(field));
  await tester.tap(find.text(field));
  await tester.pumpAndSettle();

  // Select month precision.
  await tester.tap(find.text('Month and year'));
  await tester.pumpAndSettle();

  expect(find.text('Select month and year'), findsOneWidget);

  // Select year.
  final yearDropdown = find.byType(DropdownButton<int>).first;

  final currentYear = tester.widget<DropdownButton<int>>(yearDropdown).value;

  if (currentYear != year) {
    await tester.tap(yearDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('$year').last);
    await tester.pumpAndSettle();
  }

  // Select month.
  final monthDropdown = find.byType(DropdownButton<int>).last;

  final currentMonth = tester.widget<DropdownButton<int>>(monthDropdown).value;

  if (currentMonth != month) {
    final monthLabel = MaterialLocalizations.of(
      tester.element(monthDropdown),
    ).formatMonthYear(DateTime(year, month));

    await tester.tap(monthDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text(monthLabel).last);
    await tester.pumpAndSettle();
  }

  // Confirm selection.
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> selectVisitYear(
  WidgetTester tester, {
  required String field,
  required int year,
}) async {
  await tester.ensureVisible(find.text(field));
  await tester.tap(find.text(field));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Year only'));
  await tester.pumpAndSettle();

  expect(find.byType(YearPicker), findsOneWidget);

  final yearFinder = find.text('$year').last;

  await tester.ensureVisible(yearFinder);
  await tester.tap(yearFinder);
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pumpExplore(
    WidgetTester tester, {
    double width = 390,
    FakeCountriesRepository? repository,
    FakeCityRepository? cityRepository,
    FakeCityVisitsRepository? cityVisitsRepository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = ExploreCubit(
      repository: repository ?? FakeCountriesRepository(),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityRepository>.value(
            value: cityRepository ?? FakeCityRepository(),
          ),
          RepositoryProvider<CityVisitsRepository>.value(
            value: cityVisitsRepository ?? FakeCityVisitsRepository(),
          ),
        ],
        child: BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: Scaffold(body: ExplorePage())),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // Opening and navigation
  // ---------------------------------------------------------------------------

  testWidgets('opens Add Destination from Explore', (tester) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    expect(find.text('Add Destination'), findsOneWidget);
    expect(find.text('Where have you been?'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Been'), findsOneWidget);
    expect(find.text('Lived'), findsOneWidget);
    expect(find.text('Wish'), findsOneWidget);
    expect(find.text('Save Visit'), findsOneWidget);
  });

  testWidgets('searches countries and selects a destination', (tester) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCountrySearch')),
      'port',
    );

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Save Visit'), findsOneWidget);
  });

  testWidgets('closes modal using the close button', (tester) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add Destination'), findsNothing);
  });

  testWidgets('uses a dialog on desktop', (tester) async {
    await pumpExplore(tester, width: 1200);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Add Destination'), findsOneWidget);
  });

  testWidgets('Save Visit is disabled without a selected country', (
    tester,
  ) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save Visit'),
        matching: find.byType(FilledButton),
      ),
    );

    expect(button.onPressed, isNull);
  });

  // ---------------------------------------------------------------------------
  // Country visit creation
  // ---------------------------------------------------------------------------

  testWidgets('creates a country visit and closes the modal', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    // Both dates are required.
    await selectVisitMonth(tester, field: 'START DATE', year: 2024, month: 6);

    await selectVisitMonth(tester, field: 'END DATE', year: 2024, month: 8);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedCountryCode, 'PT');

    final visit = repository.createdVisits.single;

    expect(visit.startedOn, DateTime(2024, 6, 1));
    expect(visit.endedOn, DateTime(2024, 8, 1));

    expect(visit.startedOnPrecision, VisitDatePrecision.month);

    expect(visit.endedOnPrecision, VisitDatePrecision.month);

    expect(find.text('Add Destination'), findsNothing);
  });

  testWidgets('rejects creating a country visit without dates', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(repository.createdVisits, isEmpty);

    expect(find.text('Start and end dates are required.'), findsOneWidget);

    expect(find.text('Add Destination'), findsOneWidget);
  });

  testWidgets('creates a country visit with month precision', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await selectVisitMonth(tester, field: 'START DATE', year: 2024, month: 6);

    await selectVisitMonth(tester, field: 'END DATE', year: 2024, month: 9);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);

    final visit = repository.createdVisits.single;

    expect(visit.startedOn, DateTime(2024, 6, 1));
    expect(visit.endedOn, DateTime(2024, 9, 1));

    expect(visit.startedOnPrecision, VisitDatePrecision.month);

    expect(visit.endedOnPrecision, VisitDatePrecision.month);
  });

  testWidgets('rejects a country visit with only an end date', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    // An end date can be selected independently while editing the form,
    // but the visit cannot be saved until both dates are provided.
    await selectVisitYear(tester, field: 'END DATE', year: 2024);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(repository.createdVisits, isEmpty);

    expect(find.text('Start and end dates are required.'), findsOneWidget);

    expect(find.text('Add Destination'), findsOneWidget);
  });

  testWidgets('creates a country visit with mixed precisions', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await selectVisitYear(tester, field: 'START DATE', year: 2024);

    await selectVisitMonth(tester, field: 'END DATE', year: 2024, month: 8);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);

    final visit = repository.createdVisits.single;

    expect(visit.startedOn, DateTime(2024, 1, 1));
    expect(visit.endedOn, DateTime(2024, 8, 1));

    expect(visit.startedOnPrecision, VisitDatePrecision.year);

    expect(visit.endedOnPrecision, VisitDatePrecision.month);
  });

  // ---------------------------------------------------------------------------
  // Repository scope
  // ---------------------------------------------------------------------------

  testWidgets(
    'country picker works when ExploreCubit is scoped below MaterialApp',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeCountriesRepository();
      final cubit = ExploreCubit(repository: repository);

      addTearDown(cubit.close);

      await cubit.load();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CityRepository>.value(
              value: FakeCityRepository(),
            ),
            RepositoryProvider<CityVisitsRepository>.value(
              value: FakeCityVisitsRepository(),
            ),
          ],
          child: MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: ExplorePage()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(addDestinationButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select a country'));
      await tester.pumpAndSettle();

      expect(find.text('Portugal'), findsOneWidget);
      expect(find.text('Spain'), findsOneWidget);

      await tester.tap(find.text('Portugal'));
      await tester.pumpAndSettle();

      expect(find.text('Portugal'), findsOneWidget);
      expect(find.text('Save Visit'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // City navigation and search
  // ---------------------------------------------------------------------------

  testWidgets('switches from Country to City', (tester) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    expect(find.text('Select a city'), findsOneWidget);
    expect(find.text('Select a country'), findsNothing);
  });

  testWidgets('searches and selects a city', (tester) async {
    final cityRepository = FakeCityRepository();

    await pumpExplore(tester, cityRepository: cityRepository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a city'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(cityRepository.searchCalls, 1);
    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Madrid'), findsNothing);

    await tester.tap(find.text('Lisbon'));
    await tester.pumpAndSettle();

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // City visit creation
  // ---------------------------------------------------------------------------

  testWidgets('creates a city visit without creating a country visit', (
    tester,
  ) async {
    final countriesRepository = FakeCountriesRepository();
    final cityVisitsRepository = FakeCityVisitsRepository();

    await pumpExplore(
      tester,
      repository: countriesRepository,
      cityVisitsRepository: cityVisitsRepository,
    );

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a city'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lisbon'));
    await tester.pumpAndSettle();

    await selectVisitMonth(tester, field: 'START DATE', year: 2024, month: 6);

    await selectVisitMonth(tester, field: 'END DATE', year: 2024, month: 8);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(cityVisitsRepository.createCalls, 1);
    expect(cityVisitsRepository.lastCreatedCityId, 2267057);

    final visit = cityVisitsRepository.createdVisits.single;

    expect(visit.startedOn, DateTime(2024, 6, 1));
    expect(visit.endedOn, DateTime(2024, 8, 1));

    expect(visit.startedOnPrecision, VisitDatePrecision.month);

    expect(visit.endedOnPrecision, VisitDatePrecision.month);

    // A city visit must not automatically create a country visit.
    expect(countriesRepository.createCalls, 0);

    expect(find.text('Add Destination'), findsNothing);
  });

  testWidgets('rejects creating a city visit without dates', (tester) async {
    final countriesRepository = FakeCountriesRepository();
    final cityVisitsRepository = FakeCityVisitsRepository();

    await pumpExplore(
      tester,
      repository: countriesRepository,
      cityVisitsRepository: cityVisitsRepository,
    );

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a city'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lisbon'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(cityVisitsRepository.createCalls, 0);
    expect(countriesRepository.createCalls, 0);

    expect(find.text('Start and end dates are required.'), findsOneWidget);
  });

  testWidgets('creates a city visit with month precision', (tester) async {
    final countriesRepository = FakeCountriesRepository();
    final cityVisitsRepository = FakeCityVisitsRepository();

    await pumpExplore(
      tester,
      repository: countriesRepository,
      cityVisitsRepository: cityVisitsRepository,
    );

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a city'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lisbon'));
    await tester.pumpAndSettle();

    await selectVisitMonth(tester, field: 'START DATE', year: 2024, month: 6);

    await selectVisitMonth(tester, field: 'END DATE', year: 2024, month: 9);

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(cityVisitsRepository.createCalls, 1);
    expect(cityVisitsRepository.lastCreatedCityId, 2267057);

    final visit = cityVisitsRepository.createdVisits.single;

    expect(visit.startedOn, DateTime(2024, 6, 1));
    expect(visit.endedOn, DateTime(2024, 9, 1));

    expect(visit.startedOnPrecision, VisitDatePrecision.month);

    expect(visit.endedOnPrecision, VisitDatePrecision.month);

    // Country history remains independent.
    expect(countriesRepository.createCalls, 0);
  });

  // ---------------------------------------------------------------------------
  // Repository provider placement
  // ---------------------------------------------------------------------------

  testWidgets(
    'city search works when repositories are scoped below MaterialApp on mobile',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final countriesRepository = FakeCountriesRepository();
      final cityRepository = FakeCityRepository();
      final cityVisitsRepository = FakeCityVisitsRepository();

      final cubit = ExploreCubit(repository: countriesRepository);

      addTearDown(cubit.close);

      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<CityRepository>.value(value: cityRepository),
              RepositoryProvider<CityVisitsRepository>.value(
                value: cityVisitsRepository,
              ),
            ],
            child: BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: ExplorePage()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(addDestinationButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('City'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select a city'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('destinationCitySearch')),
        'Madrid',
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cityRepository.searchCalls, 1);

      expect(
        find
            .text('Madrid')
            .evaluate()
            .where((element) => element.widget is Text),
        hasLength(1),
      );

      expect(find.text('Lisbon'), findsNothing);

      expect(
        find.text('Unable to search cities. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'city search works when repositories are scoped below MaterialApp on desktop',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 844);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final countriesRepository = FakeCountriesRepository();
      final cityRepository = FakeCityRepository();
      final cityVisitsRepository = FakeCityVisitsRepository();

      final cubit = ExploreCubit(repository: countriesRepository);

      addTearDown(cubit.close);

      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<CityRepository>.value(value: cityRepository),
              RepositoryProvider<CityVisitsRepository>.value(
                value: cityVisitsRepository,
              ),
            ],
            child: BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: ExplorePage()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(addDestinationButton);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text('City'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select a city'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('destinationCitySearch')),
        'Madrid',
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cityRepository.searchCalls, 1);

      expect(
        find
            .text('Madrid')
            .evaluate()
            .where((element) => element.widget is Text),
        hasLength(1),
      );

      expect(find.text('Lisbon'), findsNothing);

      expect(
        find.text('Unable to search cities. Please try again.'),
        findsNothing,
      );
    },
  );
  testWidgets('shows required date fields without initial errors', (
    tester,
  ) async {
    await pumpExplore(tester);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('END DATE'), findsOneWidget);

    expect(
      find.text(
        'Start and end dates are required. Choose an exact date, month, or year.',
      ),
      findsOneWidget,
    );

    expect(find.text('*'), findsNWidgets(2));
    expect(find.text('Select date'), findsNWidgets(2));

    // Errors must not be shown before submission.
    expect(find.text('Required'), findsNothing);
  });
  testWidgets('shows errors for both missing dates after submission', (
    tester,
  ) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);

    expect(find.text('Required'), findsNWidgets(2));

    expect(find.text('Start and end dates are required.'), findsOneWidget);
  });
  testWidgets('clears only the corrected date field error', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(addDestinationButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    // Trigger validation.
    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));

    // Correct only the start date.
    await selectVisitMonth(tester, field: 'START DATE', year: 2024, month: 6);

    // The start date error disappears, but the end date remains required.
    expect(find.text('Required'), findsOneWidget);

    expect(find.text('June 2024'), findsOneWidget);

    // The visit must not have been created.
    expect(repository.createCalls, 0);
  });
}
