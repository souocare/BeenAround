import 'dart:async';

import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/application/visited_cities_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';

class FakeExploreRepository implements CountriesRepository {
  FakeExploreRepository({this.countries = const [], this.visits = const []});

  List<Country> countries;
  List<CountryVisit> visits;

  Future<List<Country>> Function()? countriesHandler;

  int loadCount = 0;

  @override
  Future<List<Country>> getCountries() {
    loadCount++;

    if (countriesHandler != null) {
      return countriesHandler!();
    }

    return Future.value(countries);
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError(
      'Country visit creation is not used by this test.',
    );
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() async => visits;

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
}

class FakeCityVisitsRepository implements CityVisitsRepository {
  FakeCityVisitsRepository({this.visits = const []});

  List<CityVisit> visits;

  int loadCalls = 0;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    loadCalls++;
    return List.unmodifiable(visits);
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError();
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

const portugal = Country(
  code: 'PT',
  name: 'Portugal',
  alpha3Code: 'PRT',
  continent: 'Europe',
);

const spain = Country(
  code: 'ES',
  name: 'Spain',
  alpha3Code: 'ESP',
  continent: 'Europe',
);

CountryVisit visit(String id, String countryCode) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
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
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 24),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  Future<void> pumpExplore(
    WidgetTester tester,
    ExploreCubit cubit, {
    FakeCityVisitsRepository? cityRepository,
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<CityVisitsRepository>.value(
        value: cityRepository ?? FakeCityVisitsRepository(),
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(value: cubit, child: const ExplorePage()),
          ),
        ),
      ),
    );
  }

  Future<void> openCitiesTab(WidgetTester tester) async {
    final citiesTab = find.text('Cities');

    await tester.ensureVisible(citiesTab);
    await tester.pumpAndSettle();

    await tester.tap(citiesTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('visitedCitiesSearch')), findsOneWidget);
  }

  testWidgets('shows loading state', (tester) async {
    final pending = Completer<List<Country>>();

    final repository = FakeExploreRepository()
      ..countriesHandler = () => pending.future;

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await pumpExplore(tester, cubit);

    final loading = cubit.load();

    await tester.pump();

    expect(find.text('Loading your travel history...'), findsOneWidget);

    pending.complete([]);

    await loading;
  });

  testWidgets('shows empty state when there are no visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('No countries visited yet'), findsOneWidget);
    expect(find.text('Countries visited'), findsOneWidget);
    expect(find.text('Total visits'), findsOneWidget);
  });

  testWidgets('shows visited countries and statistics', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'PT'), visit('3', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('1 visit'), findsOneWidget);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows error state and retries', (tester) async {
    final repository = FakeExploreRepository();

    repository.countriesHandler = () async {
      throw const FormatException('Invalid response');
    };

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Unable to load Explore'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    repository.countriesHandler = () async => [portugal];

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('No countries visited yet'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('keeps existing data during refresh', (tester) async {
    final repository = FakeExploreRepository(
      countries: [portugal],
      visits: [visit('1', 'PT')],
    );

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final pending = Completer<List<Country>>();

    repository.countriesHandler = () => pending.future;

    final refresh = cubit.refresh();

    await tester.pump();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete([portugal]);

    await refresh;
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('searches visited countries by name', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'port',
    );

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    // A pesquisa não altera as estatísticas globais.
    expect(cubit.state.visitedCountryCount, 2);
  });
  testWidgets('searches visited countries by ISO codes', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final search = find.byKey(const Key('visitedCountriesSearch'));

    await tester.enterText(search, 'PRT');
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await tester.enterText(search, 'ES');
    await tester.pumpAndSettle();

    expect(find.text('Spain'), findsOneWidget);
    expect(find.text('Portugal'), findsNothing);
  });

  testWidgets('filters countries with multiple visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'PT'), visit('3', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final multipleVisitsChip = find.text('Multiple visits');

    await tester.ensureVisible(multipleVisitsChip);
    await tester.pumpAndSettle();

    await tester.tap(multipleVisitsChip);
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);
  });

  testWidgets('shows no matching countries for empty search results', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'Japan',
    );

    await tester.pumpAndSettle();

    expect(find.text('No matching countries'), findsOneWidget);
    expect(find.text('No countries visited yet'), findsNothing);
  });

  testWidgets('sorts visited countries by number of visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [
          visit('1', 'PT'),
          visit('2', 'ES'),
          visit('3', 'ES'),
          visit('4', 'ES'),
        ],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final sortField = find.byKey(const Key('visitedCountriesSort'));

    await tester.ensureVisible(sortField);
    await tester.pumpAndSettle();

    // Abrir o dropdown.
    final sortButton = find.byKey(const Key('visitedCountriesSort'));

    await tester.ensureVisible(sortButton);
    await tester.pumpAndSettle();

    await tester.tap(sortButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Most visited').last);
    await tester.pumpAndSettle();

    final portugalPosition = tester.getTopLeft(find.text('Portugal')).dy;
    final spainPosition = tester.getTopLeft(find.text('Spain')).dy;

    expect(spainPosition, lessThan(portugalPosition));
  });
  testWidgets('shows countries by default', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('country-1', 'PT')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.byKey(const Key('visitedCountriesSearch')), findsOneWidget);
    expect(find.byKey(const Key('visitedCitiesSearch')), findsNothing);
  });
  testWidgets('shows grouped visited cities', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'city-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
        cityVisit(
          id: 'city-2',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
        cityVisit(
          id: 'city-3',
          cityId: 3117735,
          cityName: 'Madrid',
          countryCode: 'ES',
          countryName: 'Spain',
        ),
      ],
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit, cityRepository: cityRepository);

    await tester.pumpAndSettle();

    await openCitiesTab(tester);
    final citySearch = find.byKey(const Key('visitedCitiesSearch'));

    expect(citySearch, findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Madrid'), findsOneWidget);
    expect(find.text('Portugal · 2 visits'), findsOneWidget);
    expect(find.text('Spain · 1 visit'), findsOneWidget);
    expect(cityRepository.loadCalls, 1);
  });
  testWidgets('filters visited cities by name', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'city-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
        cityVisit(
          id: 'city-2',
          cityId: 3117735,
          cityName: 'Madrid',
          countryCode: 'ES',
          countryName: 'Spain',
        ),
      ],
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit, cityRepository: cityRepository);

    await tester.pumpAndSettle();

    await openCitiesTab(tester);

    final searchField = find.byKey(const Key('visitedCitiesSearch'));

    await tester.ensureVisible(searchField);
    await tester.pumpAndSettle();

    await tester.enterText(searchField, 'Lisbon');

    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('visitedCityCard-2267057')),
        matching: find.text('Lisbon'),
      ),
      findsOneWidget,
    );

    expect(find.byKey(const Key('visitedCityCard-3117735')), findsNothing);
  });
  testWidgets('city visits do not mark countries as visited', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal], visits: []),
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'city-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(tester, cubit, cityRepository: cityRepository);

    await tester.pumpAndSettle();

    expect(cubit.state.visitedCountryCount, 0);
    expect(cubit.state.visitedCountryCodes, isEmpty);

    await openCitiesTab(tester);

    await tester.pumpAndSettle();

    expect(find.text('Lisbon'), findsOneWidget);
  });
}
