import 'dart:async';

import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/explore/presentation/pages/city_details_page.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';

import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';

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
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
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

class FakeCityVisitsRepository implements CityVisitsRepository {
  FakeCityVisitsRepository({this.visits = const []});

  List<CityVisit> visits;

  int loadCalls = 0;
  int deleteCalls = 0;
  String? receivedDeletedVisitId;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    loadCalls++;
    return List.unmodifiable(visits);
  }

  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
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
  Future<void> deleteCityVisit({required String visitId}) async {
    deleteCalls++;
    receivedDeletedVisitId = visitId;

    visits = visits.where((visit) => visit.id != visitId).toList();
  }
}

class FakeCityRepository implements CityRepository {
  FakeCityRepository({this.cities = const []});

  List<City> cities;

  int resolveCalls = 0;

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    resolveCalls++;

    final citiesById = {for (final city in cities) city.id: city};

    return [
      for (final id in cityIds.toSet())
        if (citiesById.containsKey(id)) citiesById[id]!,
    ];
  }

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    return CitySearchResult(
      items: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    return const [];
  }
}

class FakeResidenceRepository implements ResidenceRepository {
  FakeResidenceRepository({this.residences = const []});

  List<Residence> residences;

  int loadCalls = 0;

  @override
  Future<List<Residence>> getResidences() async {
    loadCalls++;
    return List.unmodifiable(residences);
  }

  @override
  Future<Residence> getResidence({required String residenceId}) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteResidence({required String residenceId}) {
    throw UnimplementedError();
  }
}

class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({this.entries = const []});

  List<WishlistEntry> entries;

  int loadCalls = 0;

  @override
  Future<List<WishlistEntry>> getWishlistEntries() async {
    loadCalls++;
    return List.unmodifiable(entries);
  }

  @override
  Future<WishlistEntry> getWishlistEntry({required String entryId}) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWishlistEntry({required String entryId}) {
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

Residence residence({
  required String id,
  required String countryCode,
  int? cityId,
}) {
  return Residence(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    startedOn: DateTime(2024, 1, 1),
    startedOnPrecision: VisitDatePrecision.day,
    endedOn: DateTime(2025, 1, 1),
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

WishlistEntry wishlistCountry({
  required String id,
  required String countryCode,
}) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: null,
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
    FakeCityRepository? catalogRepository,
    FakeResidenceRepository? residenceRepository,
    FakeWishlistRepository? wishlistRepository,
    Size screenSize = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityVisitsRepository>.value(
            value: cityRepository ?? FakeCityVisitsRepository(),
          ),
          RepositoryProvider<CityRepository>.value(
            value: catalogRepository ?? FakeCityRepository(),
          ),
          RepositoryProvider<ResidenceRepository>.value(
            value: residenceRepository ?? FakeResidenceRepository(),
          ),
          RepositoryProvider<WishlistRepository>.value(
            value: wishlistRepository ?? FakeWishlistRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(value: cubit, child: const ExplorePage()),
          ),
        ),
      ),
    );
  }

  Future<void> selectCountryFilter(WidgetTester tester, String filter) async {
    final finder = find.byKey(Key('countryFilter-$filter'));

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.tap(finder);
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(finder);

    expect(
      chip.selected,
      isTrue,
      reason: 'Country filter "$filter" should be selected.',
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

    // Wait for ResidencesCubit and WishlistCubit to finish loading.
    await tester.pumpAndSettle();

    expect(find.text('No destinations yet'), findsOneWidget);
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

    // Wait for all country aggregation sources.
    await tester.pumpAndSettle();

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

    expect(find.text('No destinations yet'), findsOneWidget);
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

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'port',
    );

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    // Search must not change global visit statistics.
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

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'Japan',
    );

    await tester.pumpAndSettle();

    expect(find.text('No matching countries'), findsOneWidget);
    expect(find.text('No destinations yet'), findsNothing);
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
  testWidgets('opens city details when tapping a visited city', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal], visits: []),
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'lisbon-visit',
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

    await openCitiesTab(tester);

    final cityCard = find.byKey(const Key('visitedCityCard-2267057'));

    await tester.ensureVisible(cityCard);
    await tester.pumpAndSettle();

    await tester.tap(cityCard);
    await tester.pumpAndSettle();

    expect(find.byType(CityDetailsPage), findsOneWidget);
    expect(find.text('City Details'), findsOneWidget);
    expect(find.text('Lisbon'), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-lisbon-visit')), findsOneWidget);
  });
  testWidgets('deleting last city visit removes city from Explore', (
    tester,
  ) async {
    final countryRepository = FakeExploreRepository(
      countries: [portugal],
      visits: [visit('country-1', 'PT')],
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'lisbon-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    final cubit = ExploreCubit(repository: countryRepository);
    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(tester, cubit, cityRepository: cityRepository);

    await openCitiesTab(tester);

    expect(find.byKey(const Key('visitedCityCard-2267057')), findsOneWidget);

    // Abrir City Details.
    await tester.tap(find.byKey(const Key('visitedCityCard-2267057')));
    await tester.pumpAndSettle();

    expect(find.text('City Details'), findsOneWidget);

    // Abrir menu da visita.
    await tester.tap(find.byKey(const Key('cityVisitMenu-lisbon-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    // Confirmar eliminação.
    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    // A última visita desapareceu.
    expect(cityRepository.deleteCalls, 1);
    expect(cityRepository.receivedDeletedVisitId, 'lisbon-1');

    expect(cityRepository.visits, isEmpty);

    // Regressámos ao Explore.
    expect(find.text('City Details'), findsNothing);

    // A cidade já não aparece na lista.
    expect(find.byKey(const Key('visitedCityCard-2267057')), findsNothing);

    expect(find.text('No cities visited yet'), findsOneWidget);

    // O registo independente do país permanece.
    expect(countryRepository.visits, hasLength(1));
    expect(countryRepository.visits.single.id, 'country-1');
  });
  testWidgets('deleting one of multiple visits keeps city in Explore', (
    tester,
  ) async {
    final countryRepository = FakeExploreRepository(
      countries: [portugal],
      visits: [visit('country-1', 'PT')],
    );

    final cityRepository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'lisbon-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
        cityVisit(
          id: 'lisbon-2',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    final cubit = ExploreCubit(repository: countryRepository);
    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(tester, cubit, cityRepository: cityRepository);

    await openCitiesTab(tester);

    expect(find.byKey(const Key('visitedCityCard-2267057')), findsOneWidget);

    // Abrir City Details.
    await tester.tap(find.byKey(const Key('visitedCityCard-2267057')));
    await tester.pumpAndSettle();

    // Eliminar apenas a primeira visita.
    await tester.tap(find.byKey(const Key('cityVisitMenu-lisbon-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(cityRepository.deleteCalls, 1);
    expect(cityRepository.visits, hasLength(1));
    expect(cityRepository.visits.single.id, 'lisbon-2');

    // Continuamos no City Details.
    expect(find.text('City Details'), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-lisbon-1')), findsNothing);

    expect(find.byKey(const Key('cityVisit-lisbon-2')), findsOneWidget);

    // Regressar manualmente ao Explore.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // A cidade continua na lista.
    expect(find.byKey(const Key('visitedCityCard-2267057')), findsOneWidget);

    expect(find.text('Portugal · 1 visit'), findsOneWidget);

    // A visita ao país permanece inalterada.
    expect(countryRepository.visits, hasLength(1));
    expect(countryRepository.visits.single.id, 'country-1');
  });
  testWidgets('shows floating add button after scrolling past the header', (
    tester,
  ) async {
    final repository = FakeExploreRepository(
      countries: [
        portugal,
        spain,
        for (var i = 0; i < 30; i++)
          Country(
            code: 'T$i',
            name: 'Test Country $i',
            alpha3Code: 'TST',
            continent: 'Europe',
          ),
      ],
      visits: [
        for (var i = 0; i < 20; i++) visit('visit-pt-$i', 'PT'),
        for (var i = 0; i < 20; i++) visit('visit-es-$i', 'ES'),
      ],
    );

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(tester, cubit, screenSize: const Size(390, 500));

    final floatingButton = find.byKey(const Key('exploreFloatingAddButton'));

    expect(floatingButton, findsOneWidget);

    FloatingActionButton button = tester.widget(floatingButton);

    expect(button.onPressed, isNotNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));

    await tester.pumpAndSettle();

    button = tester.widget(floatingButton);

    expect(button.onPressed, isNotNull);

    final animatedOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(of: floatingButton, matching: find.byType(AnimatedOpacity))
          .first,
    );

    expect(animatedOpacity.opacity, 1);
  });
  testWidgets('hides floating add button when returning to the top', (
    tester,
  ) async {
    final repository = FakeExploreRepository(
      countries: [portugal, spain],
      visits: [
        for (var i = 0; i < 20; i++) visit('visit-pt-$i', 'PT'),
        for (var i = 0; i < 20; i++) visit('visit-es-$i', 'ES'),
      ],
    );

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(tester, cubit, screenSize: const Size(390, 844));

    final floatingButton = find.byKey(const Key('exploreFloatingAddButton'));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));

    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));

    await tester.pumpAndSettle();

    final animatedOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(of: floatingButton, matching: find.byType(AnimatedOpacity))
          .first,
    );

    expect(animatedOpacity.opacity, 0);
  });
  testWidgets(
    'loads aggregated cities when all source repositories are ready',
    (tester) async {
      final countriesRepository = FakeExploreRepository();

      final exploreCubit = ExploreCubit(repository: countriesRepository);

      addTearDown(exploreCubit.close);

      await exploreCubit.load();

      final cityVisitsRepository = FakeCityVisitsRepository(
        visits: [
          cityVisit(
            id: 'visit-1',
            cityId: 100,
            cityName: 'Lisbon',
            countryCode: 'PT',
            countryName: 'Portugal',
          ),
        ],
      );

      final cityCatalogRepository = FakeCityRepository(
        cities: const [
          City(
            id: 100,
            name: 'Lisbon',
            asciiName: 'Lisbon',
            countryCode: 'PT',
            countryName: 'Portugal',
            latitude: 38.72,
            longitude: -9.13,
            population: 500000,
            featureCode: 'PPLC',
          ),
        ],
      );

      await pumpExplore(
        tester,
        exploreCubit,
        cityRepository: cityVisitsRepository,
        catalogRepository: cityCatalogRepository,
      );

      await tester.pumpAndSettle();

      expect(cityCatalogRepository.resolveCalls, 1);
    },
  );
  testWidgets('switching tabs does not resolve cities again', (tester) async {
    final exploreCubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal]),
    );
    addTearDown(exploreCubit.close);

    await exploreCubit.load();

    final catalog = FakeCityRepository(
      cities: const [
        City(
          id: 100,
          name: 'Lisbon',
          asciiName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          latitude: 38.72,
          longitude: -9.13,
          population: 500000,
          featureCode: 'PPLC',
        ),
      ],
    );

    await pumpExplore(
      tester,
      exploreCubit,
      catalogRepository: catalog,
      cityRepository: FakeCityVisitsRepository(
        visits: [
          cityVisit(
            id: 'visit-1',
            cityId: 100,
            cityName: 'Lisbon',
            countryCode: 'PT',
            countryName: 'Portugal',
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(catalog.resolveCalls, 1);

    await openCitiesTab(tester);

    await tester.tap(find.text('Countries'));
    await tester.pumpAndSettle();

    expect(catalog.resolveCalls, 1);
  });
  testWidgets('pull-to-refresh resolves updated city history', (tester) async {
    final exploreCubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal]),
    );
    addTearDown(exploreCubit.close);

    await exploreCubit.load();

    final catalog = FakeCityRepository(
      cities: const [
        City(
          id: 100,
          name: 'Lisbon',
          asciiName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          latitude: 38.72,
          longitude: -9.13,
          population: 500000,
          featureCode: 'PPLC',
        ),
        City(
          id: 200,
          name: 'Porto',
          asciiName: 'Porto',
          countryCode: 'PT',
          countryName: 'Portugal',
          latitude: 41.15,
          longitude: -8.61,
          population: 250000,
          featureCode: 'PPLA',
        ),
      ],
    );

    final cityVisits = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          cityId: 100,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    await pumpExplore(
      tester,
      exploreCubit,
      catalogRepository: catalog,
      cityRepository: cityVisits,
    );

    await tester.pumpAndSettle();

    expect(catalog.resolveCalls, 1);

    cityVisits.visits = [
      ...cityVisits.visits,
      cityVisit(
        id: 'visit-2',
        cityId: 200,
        cityName: 'Porto',
        countryCode: 'PT',
        countryName: 'Portugal',
      ),
    ];

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(cityVisits.loadCalls, 2);
    expect(catalog.resolveCalls, 2);
  });
  testWidgets('Been shows only explicitly visited countries', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('visit-1', 'PT')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);
    await tester.pumpAndSettle();

    await selectCountryFilter(tester, 'been');

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    expect(cubit.state.visitedCountryCount, 1);
  });

  testWidgets('Lived shows residence-only countries without creating visits', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(
      tester,
      cubit,
      residenceRepository: FakeResidenceRepository(
        residences: [residence(id: 'residence-1', countryCode: 'PT')],
      ),
    );

    await tester.pumpAndSettle();

    // A country with only residence history must appear in All.
    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'lived');

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await selectCountryFilter(tester, 'been');

    expect(find.text('Portugal'), findsNothing);

    // Residence history must not create explicit country visits.
    expect(cubit.state.visitedCountryCount, 0);
    expect(cubit.state.visits, isEmpty);
  });

  testWidgets('Wish shows wishlist-only countries without creating visits', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(
      tester,
      cubit,
      wishlistRepository: FakeWishlistRepository(
        entries: [wishlistCountry(id: 'wish-1', countryCode: 'ES')],
      ),
    );

    await tester.pumpAndSettle();

    // A country with only wishlist status must appear in All.
    expect(find.text('Spain'), findsOneWidget);

    await selectCountryFilter(tester, 'wish');

    expect(find.text('Spain'), findsOneWidget);
    expect(find.text('Portugal'), findsNothing);

    await selectCountryFilter(tester, 'been');

    expect(find.text('Spain'), findsNothing);

    // Wishlist must not create explicit country visits.
    expect(cubit.state.visitedCountryCount, 0);
    expect(cubit.state.visits, isEmpty);
  });

  testWidgets('All shows a country with multiple statuses only once', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('visit-1', 'PT')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(
      tester,
      cubit,
      residenceRepository: FakeResidenceRepository(
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 2267057),
        ],
      ),
      wishlistRepository: FakeWishlistRepository(
        entries: [wishlistCountry(id: 'wish-1', countryCode: 'PT')],
      ),
    );

    await tester.pumpAndSettle();

    // All must contain Portugal once, despite having three statuses.
    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'been');

    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'lived');

    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'wish');

    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'all');

    expect(find.text('Portugal'), findsOneWidget);

    // The underlying country history remains unchanged.
    expect(cubit.state.visits, hasLength(1));
  });

  testWidgets('city residence contributes to country Lived, not Been', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal]),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await pumpExplore(
      tester,
      cubit,
      residenceRepository: FakeResidenceRepository(
        residences: [
          residence(id: 'lisbon-residence', countryCode: 'PT', cityId: 2267057),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await selectCountryFilter(tester, 'lived');

    expect(find.text('Portugal'), findsOneWidget);

    await selectCountryFilter(tester, 'been');

    expect(find.text('Portugal'), findsNothing);

    // A city residence must not create a country visit.
    expect(cubit.state.visits, isEmpty);
    expect(cubit.state.visitedCountryCount, 0);
  });
}
