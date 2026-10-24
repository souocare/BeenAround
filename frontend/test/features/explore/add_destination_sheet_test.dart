import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';

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
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
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

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    createCalls++;
    lastCreatedCountryCode = countryCode;

    final visit = CountryVisit(
      id: 'visit-$createCalls',
      countryCode: countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      createdAt: DateTime(2026, 10, 21),
      updatedAt: DateTime(2026, 10, 21),
    );

    createdVisits.add(visit);

    return visit;
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
    DateTime? startedOn,
    DateTime? endedOn,
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

  testWidgets('opens Add Destination from Explore', (tester) async {
    await pumpExplore(tester);

    await tester.tap(find.byTooltip('Add Destination'));
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

    await tester.tap(find.byTooltip('Add Destination'));
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

    await tester.tap(find.byTooltip('Add Destination'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add Destination'), findsNothing);
  });

  testWidgets('uses a dialog on desktop', (tester) async {
    await pumpExplore(tester, width: 1200);

    await tester.tap(find.byTooltip('Add Destination'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Add Destination'), findsOneWidget);
  });

  testWidgets('Save Visit is disabled without a selected country', (
    tester,
  ) async {
    await pumpExplore(tester);

    await tester.tap(find.byTooltip('Add Destination'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save Visit'),
        matching: find.byType(FilledButton),
      ),
    );

    expect(button.onPressed, isNull);
  });
  testWidgets('creates a country visit and closes the modal', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpExplore(tester, repository: repository);

    await tester.tap(find.byTooltip('Add Destination'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a country'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedCountryCode, 'PT');

    expect(find.text('Add Destination'), findsNothing);
  });
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

      await tester.tap(find.byTooltip('Add Destination'));
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
  testWidgets('switches from Country to City', (tester) async {
    await pumpExplore(tester);

    await tester.tap(find.byTooltip('Add Destination'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    expect(find.text('Select a city'), findsOneWidget);
    expect(find.text('Select a country'), findsNothing);
  });
  testWidgets('searches and selects a city', (tester) async {
    final cityRepository = FakeCityRepository();

    await pumpExplore(tester, cityRepository: cityRepository);

    await tester.tap(find.byTooltip('Add Destination'));
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

    await tester.tap(find.byTooltip('Add Destination'));
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

    expect(cityVisitsRepository.createCalls, 1);
    expect(cityVisitsRepository.lastCreatedCityId, 2267057);

    expect(countriesRepository.createCalls, 0);

    expect(find.text('Add Destination'), findsNothing);
  });
}
