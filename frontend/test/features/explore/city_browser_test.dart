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
    this.searchOverride,
  });

  final List<CountryCityCount> countries;
  final Object? loadError;
  final Future<List<CountryCityCount>>? pendingCountries;

  int countryCountCalls = 0;

  final List<City> cities;
  final Future<CitySearchResult> Function({
    String? query,
    String? countryCode,
    CitySort sort,
    int limit,
    int offset,
  })?
  searchOverride;

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
    if (searchOverride != null) {
      return searchOverride!(
        query: query,
        countryCode: countryCode,
        sort: sort,
        limit: limit,
        offset: offset,
      );
    }

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

  List<City> generateCities({
    required int count,
    String countryCode = 'PT',
    String countryName = 'Portugal',
  }) {
    return List.generate(
      count,
      (index) => City(
        id: 100000 + index,
        name: 'Test City ${index + 1}',
        asciiName: 'Test City ${index + 1}',
        countryCode: countryCode,
        countryName: countryName,
        latitude: 38.0,
        longitude: -9.0,
        population: 100000 - index,
        featureCode: 'PPL',
      ),
    );
  }

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

  Future<void> scrollToPaginationSummary(
    WidgetTester tester, {
    required String listKey,
    required String summary,
  }) async {
    await tester.scrollUntilVisible(
      find.text(summary),
      300,
      scrollable: find.descendant(
        of: find.byKey(Key(listKey)),
        matching: find.byType(Scrollable),
      ),
    );
  }

  Future<void> scrollToCountryLoadMore(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('cityBrowserCountryLoadMore')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('cityBrowserCities')),
        matching: find.byType(Scrollable),
      ),
    );
  }

  Future<void> scrollToGlobalLoadMore(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('cityBrowserGlobalLoadMore')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('cityBrowserCountries')),
        matching: find.byType(Scrollable),
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
  testWidgets('loads country cities in pages of 30', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: generateCities(count: 65),
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(repository.lastOffset, 0);

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 30 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 60 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 3);
    expect(repository.lastOffset, 60);

    await scrollToPaginationSummary(
      tester,
      listKey: 'cityBrowserCities',
      summary: 'Showing 65 of 65',
    );

    expect(find.text('Showing 65 of 65'), findsOneWidget);

    expect(find.byKey(const Key('cityBrowserCountryLoadMore')), findsNothing);
  });
  testWidgets('loads global search results in pages of 30', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: generateCities(count: 65),
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Test City',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(repository.lastOffset, 0);

    await scrollToGlobalLoadMore(tester);

    expect(find.text('Showing 30 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserGlobalLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    await scrollToGlobalLoadMore(tester);

    expect(find.text('Showing 60 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserGlobalLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 3);
    expect(repository.lastOffset, 60);

    await scrollToPaginationSummary(
      tester,
      listKey: 'cityBrowserCountries',
      summary: 'Showing 65 of 65',
    );

    expect(find.text('Showing 65 of 65'), findsOneWidget);

    expect(find.byKey(const Key('cityBrowserGlobalLoadMore')), findsNothing);
  });
  testWidgets('changing global query resets pagination', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: generateCities(count: 65),
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Test City',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await scrollToGlobalLoadMore(tester);

    await tester.tap(find.byKey(const Key('cityBrowserGlobalLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.lastOffset, 30);

    await tester.enterText(
      find.byKey(const Key('destinationCitySearch')),
      'Test City 1',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.lastOffset, 0);
    expect(repository.lastQuery, 'Test City 1');

    expect(find.text('Showing 11 of 11'), findsOneWidget);
  });
  testWidgets('changing sort resets country pagination', (tester) async {
    final repository = FakeCityRepository(
      countries: [portugal],
      cities: generateCities(count: 65),
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await scrollToCountryLoadMore(tester);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.lastOffset, 30);

    await tester.tap(find.byKey(const Key('cityBrowserSort')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Name A–Z').last);
    await tester.pumpAndSettle();

    expect(repository.lastOffset, 0);
    expect(repository.lastSort, CitySort.name);

    expect(find.text('Showing 30 of 65'), findsOneWidget);
  });
  testWidgets('preserves country cities when loading next page fails', (
    tester,
  ) async {
    var failNextPage = true;

    final allCities = generateCities(count: 65);

    final repository = FakeCityRepository(
      countries: [portugal],
      searchOverride:
          ({
            String? query,
            String? countryCode,
            CitySort sort = CitySort.population,
            int limit = 20,
            int offset = 0,
          }) async {
            if (offset == 30 && failNextPage) {
              failNextPage = false;
              throw Exception('Temporary API failure');
            }

            return CitySearchResult(
              items: allCities.skip(offset).take(limit).toList(),
              total: allCities.length,
              limit: limit,
              offset: offset,
            );
          },
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 30 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    // Os resultados anteriores devem continuar disponíveis.
    expect(find.text('Showing 30 of 65'), findsOneWidget);

    // O erro deve permitir repetir o pedido.
    expect(find.text('Unable to load more cities.'), findsOneWidget);
    expect(find.byKey(const Key('cityBrowserCountryLoadMore')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 3);
    expect(repository.lastOffset, 30);

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 60 of 65'), findsOneWidget);
    expect(find.text('Unable to load more cities.'), findsNothing);
  });
  testWidgets('prevents concurrent country pagination requests', (
    tester,
  ) async {
    final nextPageCompleter = Completer<CitySearchResult>();
    final allCities = generateCities(count: 65);

    final repository = FakeCityRepository(
      countries: [portugal],
      searchOverride:
          ({
            String? query,
            String? countryCode,
            CitySort sort = CitySort.population,
            int limit = 20,
            int offset = 0,
          }) async {
            if (offset == 30) {
              return nextPageCompleter.future;
            }

            return CitySearchResult(
              items: allCities.skip(offset).take(limit).toList(),
              total: allCities.length,
              limit: limit,
              offset: offset,
            );
          },
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await scrollToCountryLoadMore(tester);

    // Primeiro pedido de paginação.
    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pump();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    // O botão deixa de estar disponível enquanto o pedido decorre.
    expect(find.byKey(const Key('cityBrowserCountryLoadMore')), findsNothing);

    // Concluir o pedido pendente.
    nextPageCompleter.complete(
      CitySearchResult(
        items: allCities.skip(30).take(30).toList(),
        total: allCities.length,
        limit: 30,
        offset: 30,
      ),
    );

    await tester.pumpAndSettle();

    // Não houve pedidos duplicados.
    expect(repository.searchCalls, 2);

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 60 of 65'), findsOneWidget);
  });
  testWidgets('ignores stale pagination results after changing country query', (
    tester,
  ) async {
    final stalePageCompleter = Completer<CitySearchResult>();
    final allCities = generateCities(count: 65);

    final repository = FakeCityRepository(
      countries: [portugal],
      searchOverride:
          ({
            String? query,
            String? countryCode,
            CitySort sort = CitySort.population,
            int limit = 20,
            int offset = 0,
          }) async {
            // Simula uma página antiga que demora a responder.
            if (offset == 30 && (query == null || query.isEmpty)) {
              return stalePageCompleter.future;
            }

            final normalizedQuery = query?.toLowerCase() ?? '';

            final matches = allCities.where((city) {
              return normalizedQuery.isEmpty ||
                  city.name.toLowerCase().contains(normalizedQuery);
            }).toList();

            return CitySearchResult(
              items: matches.skip(offset).take(limit).toList(),
              total: matches.length,
              limit: limit,
              offset: offset,
            );
          },
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await scrollToCountryLoadMore(tester);

    // Inicia o carregamento da segunda página.
    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pump();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    // O utilizador altera a pesquisa enquanto o pedido está pendente.
    await tester.enterText(
      find.byKey(const Key('cityBrowserCountrySearch')),
      'Test City 1',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 3);
    expect(repository.lastQuery, 'Test City 1');
    expect(repository.lastOffset, 0);

    await scrollToPaginationSummary(
      tester,
      listKey: 'cityBrowserCities',
      summary: 'Showing 11 of 11',
    );

    expect(find.text('Showing 11 of 11'), findsOneWidget);

    // A resposta antiga chega depois.
    stalePageCompleter.complete(
      CitySearchResult(
        items: allCities.skip(30).take(30).toList(),
        total: allCities.length,
        limit: 30,
        offset: 30,
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.searchCalls, 3);
    expect(find.text('Showing 11 of 11'), findsOneWidget);
    expect(find.byKey(const Key('cityBrowserCountryLoadMore')), findsNothing);
  });
  testWidgets('stops country pagination after an unexpected empty page', (
    tester,
  ) async {
    final allCities = generateCities(count: 65);

    final repository = FakeCityRepository(
      countries: [portugal],
      searchOverride:
          ({
            String? query,
            String? countryCode,
            CitySort sort = CitySort.population,
            int limit = 20,
            int offset = 0,
          }) async {
            if (offset == 30) {
              return CitySearchResult(
                items: const [],
                total: 65,
                limit: limit,
                offset: offset,
              );
            }

            return CitySearchResult(
              items: allCities.skip(offset).take(limit).toList(),
              total: allCities.length,
              limit: limit,
              offset: offset,
            );
          },
    );

    await pumpBrowser(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityBrowserCountry_PT')));
    await tester.pumpAndSettle();

    await scrollToCountryLoadMore(tester);

    expect(find.text('Showing 30 of 65'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityBrowserCountryLoadMore')));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 2);
    expect(repository.lastOffset, 30);

    // Os resultados existentes continuam disponíveis.
    expect(find.text('Showing 30 of 65'), findsOneWidget);

    // A paginação termina para evitar repetir o mesmo pedido.
    expect(find.byKey(const Key('cityBrowserCountryLoadMore')), findsNothing);
  });
}
