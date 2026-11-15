import 'package:beenaround/features/explore/application/country_trips_cubit.dart';
import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:beenaround/features/trips/presentation/pages/trip_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/presentation/widgets/edit_country_visit_sheet.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';
import '../residences/application/fake_residence_repository.dart';
import '../wishlist/application/fake_wishlist_repository.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/explore/presentation/pages/country_details_page.dart';
import 'package:beenaround/features/explore/application/visited_cities_cubit.dart';
import 'package:beenaround/features/residences/application/residences_cubit.dart';
import 'package:beenaround/features/wishlist/application/wishlist_cubit.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({
    required this.countries,
    required List<CountryVisit> visits,
  }) : visits = List.of(visits);

  final List<Country> countries;
  final List<CountryVisit> visits;

  int updateCalls = 0;

  String? receivedVisitId;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;
  Map<String, dynamic>? receivedChanges;

  int deleteCalls = 0;
  String? receivedDeletedVisitId;

  Future<void> Function()? deleteHandler;

  Future<CountryVisit> Function()? updateHandler;

  @override
  Future<List<Country>> getCountries() async => countries;

  @override
  Future<List<CountryVisit>> getCountryVisits() async =>
      List.unmodifiable(visits);

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;

    receivedVisitId = visitId;
    receivedChanges = Map<String, dynamic>.of(changes);
    receivedStartedOn = changes['started_on'] as DateTime?;
    receivedEndedOn = changes['ended_on'] as DateTime?;

    if (updateHandler != null) {
      return updateHandler!();
    }

    final index = visits.indexWhere((visit) => visit.id == visitId);

    if (index == -1) {
      throw StateError('Visit not found.');
    }

    final previous = visits[index];

    final updated = CountryVisit(
      id: previous.id,
      countryCode: previous.countryCode,
      startedOn: changes.containsKey('started_on')
          ? receivedStartedOn
          : previous.startedOn,
      endedOn: changes.containsKey('ended_on')
          ? receivedEndedOn
          : previous.endedOn,
      startedOnPrecision: changes.containsKey('started_on_precision')
          ? changes['started_on_precision'] as VisitDatePrecision?
          : previous.startedOnPrecision,
      endedOnPrecision: changes.containsKey('ended_on_precision')
          ? changes['ended_on_precision'] as VisitDatePrecision?
          : previous.endedOnPrecision,
      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 10, 22),
    );

    visits[index] = updated;

    return updated;
  }

  int createCalls = 0;
  String? receivedCreatedCountryCode;

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) async {
    createCalls++;
    receivedCreatedCountryCode = countryCode;

    final created = CountryVisit(
      id: 'created-$createCalls',
      countryCode: countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      createdAt: DateTime(2026, 10, 22),
      updatedAt: DateTime(2026, 10, 22),
    );

    visits.add(created);

    return created;
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) async {
    deleteCalls++;
    receivedDeletedVisitId = visitId;

    if (deleteHandler != null) {
      await deleteHandler!();
      return;
    }

    visits.removeWhere((visit) => visit.id == visitId);
  }
}

class FakeCityVisitsRepository implements CityVisitsRepository {
  FakeCityVisitsRepository({List<CityVisit> visits = const []})
    : visits = List.of(visits);

  final List<CityVisit> visits;

  @override
  Future<List<CityVisit>> getCityVisits() async => List.unmodifiable(visits);

  @override
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
    throw UnimplementedError('City visit creation is not used by these tests.');
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError('City visit updates are not used by these tests.');
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError('City visit deletion is not used by these tests.');
  }
}

class FakeCityRepository implements CityRepository {
  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    return CitySearchResult(
      items: const <City>[],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    return const [];
  }

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) {
    throw UnimplementedError();
  }
}

CountryVisit visit({
  required String id,
  required String countryCode,
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

class FakeCountryDetailsTripRepository extends Fake implements TripRepository {
  FakeCountryDetailsTripRepository({
    List<Trip> countryTrips = const [],
    this.shouldFail = false,
  }) : countryTrips = List.of(countryTrips);

  List<Trip> countryTrips;
  bool shouldFail;

  int countryTripsCalls = 0;
  String? requestedCountryCode;

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<List<Trip>> getTripsForCountry({required String countryCode}) async {
    countryTripsCalls++;
    requestedCountryCode = countryCode;

    if (shouldFail) {
      throw StateError('Server unavailable.');
    }

    return List.unmodifiable(countryTrips);
  }

  @override
  Future<Trip> getTrip({required String tripId}) async {
    return countryTrips.singleWhere((trip) => trip.id == tripId);
  }
}

class FakeCountryDetailsTripAssociationRepository extends Fake
    implements TripAssociationRepository {
  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    throw UnimplementedError(
      'Trip association is not exercised by these tests.',
    );
  }

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) async {
    return const [];
  }

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) async {
    return const [];
  }

  @override
  Future<List<Flight>> getFlights({required String tripId}) async {
    return const [];
  }
}

class FakeNavigationFlightRepository extends Fake implements FlightRepository {}

class FakeNavigationAirportRepository extends Fake
    implements AirportRepository {}

class FakeNavigationAirlineRepository extends Fake
    implements AirlineRepository {}

CityVisit cityVisit({
  required String id,
  required int cityId,
  required String cityName,
  String countryCode = 'PT',
  String countryName = 'Portugal',
}) {
  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: DateTime(2026, 5, 1),
    endedOn: DateTime(2026, 5, 5),
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
}

Trip makeCountryTrip({
  required String id,
  required String name,
  String? description,
}) {
  return Trip(
    id: id,
    name: name,
    description: description,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

void main() {
  const portugal = Country(
    code: 'PT',
    name: 'Portugal',
    alpha3Code: 'PRT',
    continent: 'Europe',
  );
  Future<void> openPortugalDetails(WidgetTester tester) async {
    final portugalFinder = find.text('Portugal');

    await tester.scrollUntilVisible(
      portugalFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    await tester.tap(portugalFinder);
    await tester.pumpAndSettle();
  }

  Future<void> openVisitActions(WidgetTester tester, {int index = 0}) async {
    final actions = find.byTooltip('Visit actions').at(index);

    await tester.scrollUntilVisible(
      actions,
      200,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.pumpAndSettle();

    await tester.tap(actions);
    await tester.pumpAndSettle();
  }

  Future<void> pumpExplore(
    WidgetTester tester, {
    required List<CountryVisit> visits,
    FakeCountriesRepository? repository,
    Size size = const Size(390, 844),
    List<CityVisit> cityVisits = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final effectiveRepository =
        repository ??
        FakeCountriesRepository(countries: [portugal], visits: visits);

    final cubit = ExploreCubit(repository: effectiveRepository);

    addTearDown(cubit.close);

    await cubit.load();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityVisitsRepository>.value(
            value: FakeCityVisitsRepository(visits: cityVisits),
          ),
          RepositoryProvider<CityRepository>.value(value: FakeCityRepository()),
          RepositoryProvider<ResidenceRepository>.value(
            value: FakeResidenceRepository(),
          ),
          RepositoryProvider<WishlistRepository>.value(
            value: FakeWishlistRepository(),
          ),
          RepositoryProvider<TripRepository>(
            create: (_) => FakeCountryDetailsTripRepository(),
          ),

          RepositoryProvider<TripAssociationRepository>(
            create: (_) => FakeCountryDetailsTripAssociationRepository(),
          ),
          RepositoryProvider<FlightRepository>(
            create: (_) => FakeNavigationFlightRepository(),
          ),
          RepositoryProvider<AirportRepository>(
            create: (_) => FakeNavigationAirportRepository(),
          ),
          RepositoryProvider<AirlineRepository>(
            create: (_) => FakeNavigationAirlineRepository(),
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
  }

  Future<void> pumpCountryDetails(
    WidgetTester tester, {
    required List<CountryVisit> visits,
    List<CityVisit> cityVisits = const [],
    FakeCountryDetailsTripRepository? tripRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final countriesRepository = FakeCountriesRepository(
      countries: [portugal],
      visits: visits,
    );

    final cityVisitsRepository = FakeCityVisitsRepository(visits: cityVisits);

    final residencesRepository = FakeResidenceRepository();
    final wishlistRepository = FakeWishlistRepository();

    final exploreCubit = ExploreCubit(repository: countriesRepository);

    final visitedCitiesCubit = VisitedCitiesCubit(
      repository: cityVisitsRepository,
    );

    final residencesCubit = ResidencesCubit(repository: residencesRepository);

    final wishlistCubit = WishlistCubit(repository: wishlistRepository);

    final effectiveTripRepository =
        tripRepository ?? FakeCountryDetailsTripRepository();

    final countryTripsCubit = CountryTripsCubit(
      repository: effectiveTripRepository,
      countryCode: portugal.code,
    );

    addTearDown(countryTripsCubit.close);

    await countryTripsCubit.load();

    addTearDown(exploreCubit.close);
    addTearDown(visitedCitiesCubit.close);
    addTearDown(residencesCubit.close);
    addTearDown(wishlistCubit.close);

    await Future.wait([
      exploreCubit.load(),
      visitedCitiesCubit.load(),
      residencesCubit.refresh(),
      wishlistCubit.refresh(),
    ]);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CountriesRepository>.value(
            value: countriesRepository,
          ),
          RepositoryProvider<CityRepository>(
            create: (_) => FakeCityRepository(),
          ),
          RepositoryProvider<CityVisitsRepository>.value(
            value: cityVisitsRepository,
          ),
          RepositoryProvider<ResidenceRepository>.value(
            value: residencesRepository,
          ),
          RepositoryProvider<WishlistRepository>.value(
            value: wishlistRepository,
          ),
          RepositoryProvider<TripRepository>.value(
            value: effectiveTripRepository,
          ),
          RepositoryProvider<TripAssociationRepository>.value(
            value: FakeCountryDetailsTripAssociationRepository(),
          ),

          // Dependencies required when opening Trip Details.
          RepositoryProvider<FlightRepository>(
            create: (_) => FakeNavigationFlightRepository(),
          ),
          RepositoryProvider<AirportRepository>(
            create: (_) => FakeNavigationAirportRepository(),
          ),
          RepositoryProvider<AirlineRepository>(
            create: (_) => FakeNavigationAirlineRepository(),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ExploreCubit>.value(value: exploreCubit),
            BlocProvider<VisitedCitiesCubit>.value(value: visitedCitiesCubit),
            BlocProvider<ResidencesCubit>.value(value: residencesCubit),
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            BlocProvider<CountryTripsCubit>.value(value: countryTripsCubit),
          ],
          child: MaterialApp(home: CountryDetailsPage(country: portugal)),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('opens country details from Explore', (tester) async {
    await pumpExplore(
      tester,
      visits: [visit(id: '1', countryCode: 'PT')],
    );

    await openPortugalDetails(tester);

    expect(find.text('Visit History'), findsOneWidget);
    expect(find.text('VISITS'), findsOneWidget);
    expect(find.text('Dates not specified'), findsOneWidget);
  });

  testWidgets('shows multiple visits with dates', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(
          id: '1',
          countryCode: 'PT',
          startedOn: DateTime(2024, 6, 2),
          endedOn: DateTime(2024, 6, 8),
        ),
        visit(
          id: '2',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await openPortugalDetails(tester);

    expect(find.text('Visit 1'), findsOneWidget);
    expect(find.text('Visit 2'), findsOneWidget);

    expect(find.text('10–15 Oct 2026'), findsOneWidget);
    expect(find.text('2–8 Jun 2024'), findsOneWidget);
  });

  testWidgets('supports visits without an end date', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(id: '1', countryCode: 'PT', startedOn: DateTime(2025, 3, 12)),
      ],
    );

    await openPortugalDetails(tester);

    expect(find.text('From 12 Mar 2025'), findsOneWidget);
  });
  testWidgets('opens edit visit with existing dates', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    final editSheet = find.byType(EditCountryVisitSheet);

    expect(editSheet, findsOneWidget);

    expect(
      find.descendant(of: editSheet, matching: find.text('Edit Visit')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: editSheet, matching: find.text('10/10/2026')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: editSheet, matching: find.text('15/10/2026')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: editSheet, matching: find.text('Save Changes')),
      findsOneWidget,
    );
  });
  testWidgets('updates visit end date and refreshes country details', (
    tester,
  ) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);
    await openVisitActions(tester);

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitEndDate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');

    expect(repository.receivedChanges, {
      'ended_on': DateTime(2026, 10, 20),
      'ended_on_precision': VisitDatePrecision.day,
    });

    final updated = repository.visits.single;

    expect(updated.startedOn, DateTime(2026, 10, 10));
    expect(updated.endedOn, DateTime(2026, 10, 20));

    expect(find.text('Edit Visit'), findsNothing);
    expect(find.text('10–20 Oct 2026'), findsOneWidget);
  });
  testWidgets('updates visit start date', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitStartDate')));
    await tester.pumpAndSettle();

    // Select exact date precision.
    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    // Select October 12, 2026.
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('12/10/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedChanges, {
      'started_on': DateTime(2026, 10, 12),
      'started_on_precision': VisitDatePrecision.day,
    });

    expect(find.text('12–15 Oct 2026'), findsOneWidget);
  });
  testWidgets('keeps edit form open when update fails', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    repository.updateHandler = () async {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Server unavailable.',
      );
    };

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    // Change the start date to trigger a PATCH request.
    await tester.tap(find.byKey(const Key('editVisitStartDate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(find.text('Edit Visit'), findsOneWidget);
    expect(find.text('Server unavailable.'), findsOneWidget);

    final editSheet = find.byType(EditCountryVisitSheet);

    expect(editSheet, findsOneWidget);

    expect(
      find.descendant(of: editSheet, matching: find.text('12/10/2026')),
      findsOneWidget,
    );

    expect(
      find.descendant(of: editSheet, matching: find.text('15/10/2026')),
      findsOneWidget,
    );

    expect(find.text('Save Changes'), findsOneWidget);
  });
  testWidgets('opens edit visit as dialog on desktop', (tester) async {
    await pumpExplore(
      tester,
      size: const Size(1200, 900),
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
        ),
      ],
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Edit Visit'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('10/10/2026'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('canceling deletion preserves the visit', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [visit(id: 'visit-1', countryCode: 'PT')],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    expect(find.text('Delete visit?'), findsOneWidget);
    expect(find.text('This action cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('Visit 1'), findsOneWidget);
  });
  testWidgets('deletes one visit and preserves the others', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2024, 6, 2),
        ),
        visit(
          id: 'visit-2',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
        ),
      ],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.visits, hasLength(1));

    expect(find.text('Visit History'), findsOneWidget);
    expect(find.text('VISITS'), findsOneWidget);
    expect(find.text('Visit 1'), findsOneWidget);
    expect(find.text('Visit 2'), findsNothing);
  });
  testWidgets('deleting the last visit keeps country details open', (
    tester,
  ) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [visit(id: 'visit-1', countryCode: 'PT')],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.visits, isEmpty);

    // Country Details remains open.
    expect(find.text('Visit History'), findsOneWidget);
    expect(find.text('No visits recorded for this country.'), findsOneWidget);

    expect(find.byTooltip('Visit actions'), findsNothing);

    // The user can immediately add another visit.
    expect(find.byTooltip('Add country visit'), findsOneWidget);
  });
  testWidgets('keeps confirmation open when deletion fails', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [visit(id: 'visit-1', countryCode: 'PT')],
    );

    repository.deleteHandler = () async {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Server unavailable.',
      );
    };

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await openVisitActions(tester);

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('Delete visit?'), findsOneWidget);
    expect(find.text('Server unavailable.'), findsOneWidget);

    expect(repository.visits, hasLength(1));
  });
  testWidgets('adds a visit with the current country preselected', (
    tester,
  ) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [visit(id: 'visit-1', countryCode: 'PT')],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await openPortugalDetails(tester);

    await tester.tap(find.byTooltip('Add country visit'));
    await tester.pumpAndSettle();

    expect(find.text('Add Destination'), findsOneWidget);
    expect(find.text('Save Visit'), findsOneWidget);

    // The country is already selected.
    expect(find.text('Select a country'), findsNothing);

    await tester.tap(find.text('START DATE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Year only'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('END DATE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Year only'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Visit'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.receivedCreatedCountryCode, 'PT');
    expect(repository.visits, hasLength(2));

    // The modal closes and Country Details reflects the new visit.
    expect(find.text('Add Destination'), findsNothing);
    expect(find.text('Visit 2'), findsOneWidget);

    final created = repository.visits.singleWhere(
      (visit) => visit.id == 'created-1',
    );

    expect(created.startedOn, DateTime(2024, 1, 1));
    expect(created.endedOn, DateTime(2025, 1, 1));
    expect(created.startedOnPrecision, VisitDatePrecision.year);
    expect(created.endedOnPrecision, VisitDatePrecision.year);
  });
  testWidgets('switches between country detail tabs', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
        ),
      ],
    );

    await openPortugalDetails(tester);

    expect(find.text('Visit History'), findsOneWidget);

    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();

    expect(find.text('No visited cities yet'), findsOneWidget);
    expect(find.text('Visit History'), findsNothing);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    expect(find.text('No associated trips yet'), findsOneWidget);

    await tester.tap(find.text('Visits'));
    await tester.pumpAndSettle();

    expect(find.text('Visit History'), findsOneWidget);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Visit History'), findsOneWidget);
  });
  testWidgets('shows distinct visited cities for country', (tester) async {
    await pumpCountryDetails(
      tester,
      visits: const [],
      cityVisits: [
        cityVisit(id: 'lisbon-1', cityId: 1, cityName: 'Lisbon'),
        cityVisit(id: 'lisbon-2', cityId: 1, cityName: 'Lisbon'),
        cityVisit(id: 'porto-1', cityId: 2, cityName: 'Porto'),
      ],
    );

    // Navigate to Cities.
    await tester.ensureVisible(find.text('Cities'));
    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('countryVisitedCities')), findsOneWidget);

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Porto'), findsOneWidget);

    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('1 visit'), findsOneWidget);
  });
  testWidgets('city visits do not automatically mark country as visited', (
    tester,
  ) async {
    await pumpCountryDetails(
      tester,
      visits: const [],
      cityVisits: [cityVisit(id: 'lisbon-1', cityId: 1, cityName: 'Lisbon')],
    );

    expect(find.text('Not visited'), findsOneWidget);
    expect(find.text('0 visits'), findsOneWidget);

    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();

    expect(find.text('Lisbon'), findsOneWidget);
  });
  testWidgets('opens city details from country cities tab', (tester) async {
    await pumpCountryDetails(
      tester,
      visits: const [],
      cityVisits: [cityVisit(id: 'lisbon-1', cityId: 1, cityName: 'Lisbon')],
    );

    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('countryVisitedCity-1')));

    await tester.pumpAndSettle();

    expect(find.text('Lisbon'), findsWidgets);
  });
  testWidgets('shows empty state when country has no visited cities', (
    tester,
  ) async {
    await pumpCountryDetails(tester, visits: const [], cityVisits: const []);

    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();

    expect(find.text('No visited cities yet'), findsOneWidget);
  });
  testWidgets('shows real associated trips count', (tester) async {
    final repository = FakeCountryDetailsTripRepository(
      countryTrips: [
        makeCountryTrip(id: 'trip-1', name: 'Portugal 2025'),
        makeCountryTrip(id: 'trip-2', name: 'Portugal Road Trip'),
      ],
    );

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    expect(repository.requestedCountryCode, 'PT');
    expect(repository.countryTripsCalls, 1);

    expect(find.text('TRIPS'), findsOneWidget);

    final tripsLabel = find.text('TRIPS');

    final statisticsRow = find
        .ancestor(of: tripsLabel, matching: find.byType(Row))
        .first;

    expect(
      find.descendant(of: statisticsRow, matching: find.text('2')),
      findsOneWidget,
    );
  });
  testWidgets('shows associated trips in country details', (tester) async {
    final repository = FakeCountryDetailsTripRepository(
      countryTrips: [
        makeCountryTrip(id: 'trip-1', name: 'Portugal 2025'),
        makeCountryTrip(id: 'trip-2', name: 'Portugal Road Trip'),
      ],
    );

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    final tripsTab = find.text('Trips');

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('countryAssociatedTrips')), findsOneWidget);

    expect(find.text('Portugal 2025'), findsOneWidget);
    expect(find.text('Portugal Road Trip'), findsOneWidget);

    expect(find.byKey(const Key('countryTrip-trip-1')), findsOneWidget);

    expect(find.byKey(const Key('countryTrip-trip-2')), findsOneWidget);
  });
  testWidgets('shows empty state when no trips are associated', (tester) async {
    await pumpCountryDetails(tester, visits: const []);

    final tripsTab = find.text('Trips');

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.text('No associated trips yet'), findsOneWidget);

    expect(find.byKey(const Key('countryAssociatedTrips')), findsNothing);
  });
  testWidgets('shows retry when associated trips loading fails', (
    tester,
  ) async {
    final repository = FakeCountryDetailsTripRepository(shouldFail: true);

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    final tripsTab = find.text('Trips');

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('countryTripsError')), findsOneWidget);

    expect(find.text('Unable to load associated trips.'), findsOneWidget);

    expect(find.byKey(const Key('countryTripsRetry')), findsOneWidget);
  });
  testWidgets('retry loads associated trips after failure', (tester) async {
    final repository = FakeCountryDetailsTripRepository(shouldFail: true);

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    final tripsTab = find.text('Trips');

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('countryTripsError')), findsOneWidget);

    repository.shouldFail = false;

    repository.countryTrips = [
      makeCountryTrip(id: 'trip-1', name: 'Portugal 2025'),
    ];

    await tester.tap(find.byKey(const Key('countryTripsRetry')));

    await tester.pumpAndSettle();

    expect(repository.countryTripsCalls, 2);

    expect(find.byKey(const Key('countryTripsError')), findsNothing);

    expect(find.text('Portugal 2025'), findsOneWidget);
  });
  testWidgets('opens Trip Details from country associated trips', (
    tester,
  ) async {
    final repository = FakeCountryDetailsTripRepository(
      countryTrips: [makeCountryTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    final tripsTab = find.text('Trips');

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    final tripCard = find.byKey(const Key('countryTrip-trip-1'));

    await tester.ensureVisible(tripCard);
    await tester.tap(tripCard);
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsPage), findsOneWidget);
  });
  testWidgets('refreshes associated trips after returning', (tester) async {
    final repository = FakeCountryDetailsTripRepository(
      countryTrips: [makeCountryTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    await pumpCountryDetails(
      tester,
      visits: const [],
      tripRepository: repository,
    );

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('countryTrip-trip-1')));

    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsPage), findsOneWidget);

    // Simulate an association being removed while Trip Details is open.
    repository.countryTrips = [];

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.countryTripsCalls, 2);

    expect(find.byType(TripDetailsPage), findsNothing);

    expect(find.text('No associated trips yet'), findsOneWidget);
  });
}
