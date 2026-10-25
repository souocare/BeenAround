import 'dart:async';

import 'package:beenaround/features/explore/presentation/widgets/city_browser.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityRepository implements CityRepository {
  FakeCityRepository({
    this.countries = const [],
    this.loadError,
    this.pendingCountries,
    this.cities = const [],
  });

  final List<CountryCityCount> countries;
  final Object? loadError;
  final Future<List<CountryCityCount>>? pendingCountries;

  int countryCountCalls = 0;

  final List<City> cities;

  int searchCalls = 0;

  String? lastQuery;
  String? lastCountryCode;
  CitySort? lastSort;
  int? lastLimit;
  int? lastOffset;

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    countryCountCalls++;

    if (loadError != null) {
      throw loadError!;
    }

    if (pendingCountries != null) {
      return pendingCountries!;
    }

    return countries;
  }

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCalls++;

    lastQuery = query;
    lastCountryCode = countryCode;
    lastSort = sort;
    lastLimit = limit;
    lastOffset = offset;

    final normalizedQuery = query?.trim().toLowerCase() ?? '';

    final matches = cities.where((city) {
      final matchesCountry =
          countryCode == null || city.countryCode == countryCode;

      final matchesName =
          normalizedQuery.isEmpty ||
          city.name.toLowerCase().contains(normalizedQuery);

      return matchesCountry && matchesName;
    }).toList();

    if (sort == CitySort.name) {
      matches.sort((a, b) => a.name.compareTo(b.name));
    } else {
      matches.sort(
        (a, b) => (b.population ?? -1).compareTo(a.population ?? -1),
      );
    }

    final paginated = matches.skip(offset).take(limit).toList();

    return CitySearchResult(
      items: paginated,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }
}

void main() {
  const portugal = CountryCityCount(
    countryCode: 'PT',
    countryName: 'Portugal',
    cityCount: 850,
  );

  const france = CountryCityCount(
    countryCode: 'FR',
    countryName: 'France',
    cityCount: 1200,
  );

  const spain = CountryCityCount(
    countryCode: 'ES',
    countryName: 'Spain',
    cityCount: 2340,
  );

  const lisbon = City(
    id: 2267057,
    name: 'Lisbon',
    asciiName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    latitude: 38.7167,
    longitude: -9.1333,
    population: 517802,
    featureCode: 'PPLC',
  );

  Future<void> pumpBrowser(
    WidgetTester tester, {
    required CityRepository repository,
    VoidCallback? onBack,
    ValueChanged<City>? onCitySelected,
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<CityRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: CityBrowser(
              onBack: onBack ?? () {},
              onCitySelected: onCitySelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('loads and displays countries alphabetically', (tester) async {
    final repository = FakeCityRepository(countries: [spain, portugal, france]);

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(repository.countryCountCalls, 1);

    expect(find.text('France'), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    final franceY = tester.getTopLeft(find.text('France')).dy;
    final portugalY = tester.getTopLeft(find.text('Portugal')).dy;
    final spainY = tester.getTopLeft(find.text('Spain')).dy;

    expect(franceY, lessThan(portugalY));
    expect(portugalY, lessThan(spainY));
  });

  testWidgets('displays catalog city counts', (tester) async {
    final repository = FakeCityRepository(countries: [portugal, france]);

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('850 cities'), findsOneWidget);
    expect(find.text('1200 cities'), findsOneWidget);
  });

  testWidgets('opens a country and returns to countries', (tester) async {
    final repository = FakeCityRepository(countries: [portugal, france]);

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityBrowserCountrySearch')), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('850 cities'), findsOneWidget);
    expect(repository.countryCountCalls, 1);
  });

  testWidgets('back from countries calls onBack', (tester) async {
    var backCalls = 0;

    await pumpBrowser(
      tester,
      repository: FakeCityRepository(countries: [portugal]),
      onBack: () => backCalls++,
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));

    expect(backCalls, 1);
  });

  testWidgets('shows loading while countries are pending', (tester) async {
    final completer = Completer<List<CountryCityCount>>();

    await pumpBrowser(
      tester,
      repository: FakeCityRepository(pendingCountries: completer.future),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([portugal]);

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await pumpBrowser(tester, repository: FakeCityRepository());

    await tester.pumpAndSettle();

    expect(find.text('No countries available.'), findsOneWidget);
  });

  testWidgets('shows error when loading fails', (tester) async {
    await pumpBrowser(
      tester,
      repository: FakeCityRepository(
        loadError: StateError('Database unavailable'),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load countries. Please try again.'),
      findsOneWidget,
    );

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retry requests countries again', (tester) async {
    final repository = FakeCityRepository(
      loadError: StateError('Database unavailable'),
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(repository.countryCountCalls, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.countryCountCalls, 2);
  });
  testWidgets('loads cities for the selected country', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(repository.lastCountryCode, 'PT');
    expect(repository.lastQuery, isNull);
    expect(repository.lastSort, CitySort.population);
    expect(repository.lastLimit, 30);
    expect(repository.lastOffset, 0);

    expect(find.text('Lisbon'), findsOneWidget);
  });
  testWidgets('searches cities within the selected country', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('cityBrowserCountrySearch')),
      'Lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.lastQuery, 'Lis');
    expect(repository.lastCountryCode, 'PT');
    expect(find.text('Lisbon'), findsOneWidget);
  });
  testWidgets('changes city sorting', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserSort')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Name A–Z').last);
    await tester.pumpAndSettle();

    expect(repository.lastSort, CitySort.name);
  });
  testWidgets('selects a city', (tester) async {
    City? selectedCity;

    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(
      tester,
      repository: repository,
      onCitySelected: (city) => selectedCity = city,
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCity_2267057')));

    expect(selectedCity?.id, 2267057);
  });
  testWidgets('searches cities globally without a country filter', (
    tester,
  ) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.lastQuery, 'Lis');
    expect(repository.lastCountryCode, isNull);

    expect(find.text('Lisbon'), findsOneWidget);
  });
  testWidgets('filters countries during global search', (tester) async {
    final repository = FakeCityRepository(countries: [portugal, france, spain]);

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Port',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('France'), findsNothing);
    expect(find.text('Spain'), findsNothing);
  });
  testWidgets('selects a city from global search', (tester) async {
    City? selectedCity;

    final repository = FakeCityRepository(
      countries: [portugal],
      cities: [lisbon],
    );

    await pumpBrowser(
      tester,
      repository: repository,
      onCitySelected: (city) => selectedCity = city,
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Lis',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserGlobalCity_2267057')));

    expect(selectedCity?.id, 2267057);
  });

  testWidgets('opens a country from global search', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal, france],
      cities: [lisbon],
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Port',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));

    await tester.pumpAndSettle();

    expect(repository.lastCountryCode, 'PT');

    expect(find.byKey(const Key('cityBrowserCountrySearch')), findsOneWidget);
  });
}
