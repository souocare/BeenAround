import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/visited_cities_cubit.dart';
import 'package:beenaround/features/explore/domain/visited_city.dart';
import 'package:beenaround/features/explore/presentation/pages/city_details_page.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/presentation/pages/trip_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/residences/application/residences_cubit.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';

import 'package:beenaround/features/wishlist/application/wishlist_cubit.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  FakeCityVisitsRepository({required this.visits});

  List<CityVisit> visits;
  int loadCalls = 0;

  int deleteCalls = 0;
  String? receivedDeletedVisitId;

  Future<void> Function()? deleteHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    loadCalls++;
    return List.unmodifiable(visits);
  }

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
    throw UnimplementedError();
  }

  int updateCalls = 0;

  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CityVisit> Function()? updateHandler;

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    final index = visits.indexWhere((visit) => visit.id == visitId);

    if (index == -1) {
      throw StateError('Visit not found.');
    }

    final previous = visits[index];

    final updated = CityVisit(
      id: previous.id,
      cityId: previous.cityId,
      cityName: previous.cityName,
      countryCode: previous.countryCode,
      countryName: previous.countryName,

      countryVisitId: changes.containsKey('country_visit_id')
          ? changes['country_visit_id'] as String?
          : previous.countryVisitId,

      startedOn: changes.containsKey('started_on')
          ? changes['started_on'] as DateTime?
          : previous.startedOn,

      endedOn: changes.containsKey('ended_on')
          ? changes['ended_on'] as DateTime?
          : previous.endedOn,

      startedOnPrecision: changes.containsKey('started_on_precision')
          ? changes['started_on_precision'] as VisitDatePrecision?
          : previous.startedOnPrecision,

      endedOnPrecision: changes.containsKey('ended_on_precision')
          ? changes['ended_on_precision'] as VisitDatePrecision?
          : previous.endedOnPrecision,

      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 10, 24),
    );

    visits[index] = updated;

    return updated;
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) async {
    deleteCalls++;
    receivedDeletedVisitId = visitId;

    if (deleteHandler != null) {
      await deleteHandler!();
      return;
    }

    visits.removeWhere((visit) => visit.id == visitId);
  }
}

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({List<CountryVisit> visits = const []})
    : visits = List.of(visits);

  final List<CountryVisit> visits;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    return List.unmodifiable(visits);
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

class FakeCityDetailsTripRepository extends Fake implements TripRepository {
  FakeCityDetailsTripRepository({
    List<Trip> trips = const [],
    this.shouldFail = false,
  }) : trips = List.of(trips);

  List<Trip> trips;
  bool shouldFail;

  int loadCalls = 0;
  int detailsCalls = 0;

  int? receivedCityId;
  String? receivedTripId;

  @override
  Future<List<Trip>> getTripsForCity({required int cityId}) async {
    loadCalls++;
    receivedCityId = cityId;

    if (shouldFail) {
      throw StateError('Unable to load city trips.');
    }

    return List.unmodifiable(trips);
  }

  @override
  Future<Trip> getTrip({required String tripId}) async {
    detailsCalls++;
    receivedTripId = tripId;

    return trips.firstWhere(
      (trip) => trip.id == tripId,
      orElse: () => throw StateError('Trip not found.'),
    );
  }
}

class FakeCityDetailsTripAssociationRepository extends Fake
    implements TripAssociationRepository {
  int countryLoadCalls = 0;
  int cityLoadCalls = 0;

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) async {
    countryLoadCalls++;
    return const [];
  }

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) async {
    cityLoadCalls++;
    return const [];
  }
}

CityVisit cityVisit({
  required String id,
  int cityId = 2267057,
  String cityName = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
  DateTime? startedOn,
  DateTime? endedOn,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 10, 24);

  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: created,
    updatedAt: created,
  );
}

Trip cityTrip({required String id, required String name, String? description}) {
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

class EmptyResidenceRepository implements ResidenceRepository {
  @override
  Future<List<Residence>> getResidences() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected residence repository call: ${invocation.memberName}',
    );
  }
}

class EmptyWishlistRepository implements WishlistRepository {
  @override
  Future<List<WishlistEntry>> getWishlistEntries() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected wishlist repository call: ${invocation.memberName}',
    );
  }
}

void main() {
  const lisbonId = 2267057;

  Future<VisitedCitiesCubit> pumpCityDetails(
    WidgetTester tester,
    FakeCityVisitsRepository repository, {
    FakeCityDetailsTripRepository? tripRepository,
    FakeCityDetailsTripAssociationRepository? tripAssociationRepository,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final countriesRepository = FakeCountriesRepository();

    final cubit = VisitedCitiesCubit(repository: repository);
    await cubit.load();

    final city = VisitedCity(
      cityId: lisbonId,
      cityName: 'Lisbon',
      countryCode: 'PT',
      countryName: 'Portugal',
      visits: cubit.state.visitsForCity(lisbonId),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityVisitsRepository>.value(value: repository),
          RepositoryProvider<CountriesRepository>.value(
            value: countriesRepository,
          ),
          RepositoryProvider<TripRepository>.value(
            value: tripRepository ?? FakeCityDetailsTripRepository(),
          ),
          RepositoryProvider<TripAssociationRepository>.value(
            value:
                tripAssociationRepository ??
                FakeCityDetailsTripAssociationRepository(),
          ),
        ],
        child: BlocProvider<VisitedCitiesCubit>.value(
          value: cubit,
          child: MaterialApp(home: CityDetailsPage(city: city)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    addTearDown(cubit.close);

    return cubit;
  }

  testWidgets('shows city identity and visit count', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1'),
        cityVisit(id: 'visit-2'),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Lisbon')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cityDetailsName')), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('VISITS'), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);
  });

  testWidgets('orders dated visits newest first and undated visits last', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'old', startedOn: DateTime(2024, 6, 10)),
        cityVisit(id: 'undated'),
        cityVisit(id: 'new', startedOn: DateTime(2026, 10, 5)),
      ],
    );

    await pumpCityDetails(tester, repository);

    final newVisit = find.byKey(const Key('cityVisit-new'));
    final oldVisit = find.byKey(const Key('cityVisit-old'));
    final undatedVisit = find.byKey(const Key('cityVisit-undated'));

    expect(newVisit, findsOneWidget);
    expect(oldVisit, findsOneWidget);
    expect(undatedVisit, findsOneWidget);

    expect(
      tester.getTopLeft(newVisit).dy,
      lessThan(tester.getTopLeft(oldVisit).dy),
    );

    expect(
      tester.getTopLeft(oldVisit).dy,
      lessThan(tester.getTopLeft(undatedVisit).dy),
    );
  });

  testWidgets('shows optional visit dates correctly', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'range',
          startedOn: DateTime(2026, 10, 5),
          endedOn: DateTime(2026, 10, 10),
        ),
        cityVisit(id: 'start-only', startedOn: DateTime(2025, 6, 12)),
        cityVisit(id: 'end-only', endedOn: DateTime(2024, 3, 20)),
        cityVisit(id: 'undated'),
      ],
    );

    await pumpCityDetails(tester, repository);
    // The Overview tab shows only the three most recent visits.
    // Select Visits to verify the complete visit history.
    final visitsTab = find.byKey(const Key('cityTab-visits'));

    await tester.ensureVisible(visitsTab);
    await tester.tap(visitsTab);
    await tester.pumpAndSettle();

    expect(find.text('5 Oct 2026 – 10 Oct 2026'), findsOneWidget);
    expect(find.text('From 12 Jun 2025'), findsOneWidget);
    expect(find.text('Until 20 Mar 2024'), findsOneWidget);
    expect(find.text('Dates not specified'), findsOneWidget);
    expect(find.text('10 Oct 2026'), findsOneWidget);
  });

  testWidgets('shows an empty state when city has no visits', (tester) async {
    final repository = FakeCityVisitsRepository(visits: []);

    await pumpCityDetails(tester, repository);

    expect(find.text('No visits recorded for this city.'), findsOneWidget);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('cityLastVisited'))).data,
      '—',
    );

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('0')),
      findsOneWidget,
    );
  });

  testWidgets('updates displayed visits after cubit reload', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final cubit = await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);

    repository.visits = [cityVisit(id: 'visit-1'), cityVisit(id: 'visit-2')];

    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);

    expect(find.text('2'), findsOneWidget);
    expect(repository.loadCalls, 2);
  });

  testWidgets('only displays visits belonging to selected city', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'lisbon-visit'),
        cityVisit(
          id: 'madrid-visit',
          cityId: 3117735,
          cityName: 'Madrid',
          countryCode: 'ES',
          countryName: 'Spain',
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityVisit-lisbon-visit')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-madrid-visit')), findsNothing);

    expect(find.text('1'), findsOneWidget);
  });
  testWidgets('opens edit sheet for selected city visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit City Visit'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);
  });
  testWidgets('updates city history after editing a visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.text('10 Oct 2026 – 15 Oct 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitEndDate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');

    expect(repository.receivedChanges, {
      'ended_on': DateTime(2026, 10, 20),
      'ended_on_precision': VisitDatePrecision.day,
    });

    expect(repository.loadCalls, 2);

    final updated = repository.visits.single;

    expect(updated.startedOn, DateTime(2026, 10, 10));
    expect(updated.endedOn, DateTime(2026, 10, 20));

    expect(find.text('10 Oct 2026 – 20 Oct 2026'), findsOneWidget);
    expect(find.text('10 Oct 2026 – 15 Oct 2026'), findsNothing);
  });
  testWidgets('does not update visit when editing is cancelled', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1', startedOn: DateTime(2026, 10, 10))],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 0);
    expect(repository.loadCalls, 1);

    expect(find.text('From 10 Oct 2026'), findsOneWidget);
  });
  testWidgets('editing one visit preserves other visits', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
        cityVisit(
          id: 'visit-2',
          startedOn: DateTime(2025, 5, 20),
          endedOn: DateTime(2025, 5, 25),
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitStartDate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');

    expect(repository.receivedChanges, {
      'started_on': DateTime(2026, 10, 12),
      'started_on_precision': VisitDatePrecision.day,
    });

    final firstVisit = repository.visits.singleWhere(
      (visit) => visit.id == 'visit-1',
    );

    final secondVisit = repository.visits.singleWhere(
      (visit) => visit.id == 'visit-2',
    );

    expect(firstVisit.startedOn, DateTime(2026, 10, 12));
    expect(firstVisit.endedOn, DateTime(2026, 10, 15));

    expect(secondVisit.startedOn, DateTime(2025, 5, 20));
    expect(secondVisit.endedOn, DateTime(2025, 5, 25));

    expect(find.text('12 Oct 2026 – 15 Oct 2026'), findsOneWidget);
    expect(find.text('20 May 2025 – 25 May 2025'), findsOneWidget);
  });
  testWidgets('deletes selected city visit and refreshes history', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1', startedOn: DateTime(2026, 10, 10)),
        cityVisit(id: 'visit-2', startedOn: DateTime(2025, 5, 20)),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    expect(find.text('Delete visit?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.receivedDeletedVisitId, 'visit-1');
    expect(repository.loadCalls, 2);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsNothing);

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);

    expect(find.text('1'), findsOneWidget);
  });
  testWidgets('cancelled deletion preserves city visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancelDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(repository.loadCalls, 1);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);
  });
  testWidgets('failed deletion preserves visit and shows error', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    repository.deleteHandler = () async {
      throw StateError('Unexpected error');
    };

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.loadCalls, 1);

    expect(
      find.text('Unable to delete your visit. Please try again.'),
      findsOneWidget,
    );

    expect(find.text('Delete visit?'), findsOneWidget);
  });
  testWidgets('deleting last visit returns to previous page', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final cubit = VisitedCitiesCubit(repository: repository);
    await cubit.load();

    addTearDown(cubit.close);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final visit = repository.visits.single;

    final city = VisitedCity(
      cityId: visit.cityId,
      cityName: visit.cityName,
      countryCode: visit.countryCode,
      countryName: visit.countryName,
      visits: [visit],
    );

    final tripRepository = FakeCityDetailsTripRepository();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityVisitsRepository>.value(value: repository),
          RepositoryProvider<TripRepository>.value(value: tripRepository),
        ],
        child: BlocProvider<VisitedCitiesCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiRepositoryProvider(
                            providers: [
                              RepositoryProvider<CityVisitsRepository>.value(
                                value: repository,
                              ),
                              RepositoryProvider<TripRepository>.value(
                                value: tripRepository,
                              ),
                            ],
                            child: BlocProvider<VisitedCitiesCubit>.value(
                              value: cubit,
                              child: CityDetailsPage(city: city),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open city'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open city'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Lisbon')),
      findsOneWidget,
    );

    final detailsPage = tester.widget<CityDetailsPage>(
      find.byType(CityDetailsPage),
    );

    expect(
      detailsPage.catalogCity,
      isNull,
      reason: 'A Been-only city must use legacy visit navigation.',
    );

    expect(detailsPage.city, isNotNull);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.visits, isEmpty);

    expect(find.byType(CityDetailsPage), findsNothing);
    expect(find.text('Open city'), findsOneWidget);

    expect(cubit.state.visitedCities, isEmpty);
  });
  testWidgets('opens catalog city details without recorded visits', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(visits: []);

    final visitedCitiesCubit = VisitedCitiesCubit(repository: repository);

    final residencesCubit = ResidencesCubit(
      repository: EmptyResidenceRepository(),
    );

    final wishlistCubit = WishlistCubit(repository: EmptyWishlistRepository());

    addTearDown(visitedCitiesCubit.close);
    addTearDown(residencesCubit.close);
    addTearDown(wishlistCubit.close);

    await Future.wait([
      visitedCitiesCubit.load(),
      residencesCubit.load(),
      wishlistCubit.load(),
    ]);

    const catalogCity = City(
      id: 2267057,
      name: 'Lisbon',
      asciiName: 'Lisbon',
      countryCode: 'PT',
      countryName: 'Portugal',
      latitude: 38.72,
      longitude: -9.13,
      population: 500000,
      featureCode: 'PPLC',
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TripRepository>(
            create: (_) => FakeCityDetailsTripRepository(),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<VisitedCitiesCubit>.value(value: visitedCitiesCubit),
            BlocProvider<ResidencesCubit>.value(value: residencesCubit),
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
          ],
          child: const MaterialApp(
            home: CityDetailsPage.fromCatalog(city: catalogCity),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // City identity.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Lisbon')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('cityDetailsName')), findsOneWidget);

    expect(find.text('Portugal'), findsOneWidget);

    // No explicit visits.
    expect(find.text('No visits recorded for this city.'), findsOneWidget);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    // No associated trips.
    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    // No artificial travel statuses.
    expect(find.byKey(const Key('cityStatus-been')), findsNothing);

    expect(find.byKey(const Key('cityStatus-lived')), findsNothing);

    expect(find.byKey(const Key('cityStatus-wish')), findsNothing);

    // No visit actions are available.
    expect(find.byTooltip('Visit actions'), findsNothing);

    // Underlying records remain empty.
    expect(visitedCitiesCubit.state.visits, isEmpty);
    expect(residencesCubit.state.residences, isEmpty);
    expect(wishlistCubit.state.entries, isEmpty);
  });
  testWidgets('shows Overview tab by default', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityDetailsTabs')), findsOneWidget);

    final overview = tester.widget<Semantics>(
      find.byKey(const Key('cityTab-overview')),
    );

    expect(overview.properties.selected, isTrue);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);
  });
  testWidgets('Overview shows only three recent visits', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1', startedOn: DateTime(2026, 1, 1)),
        cityVisit(id: 'visit-2', startedOn: DateTime(2026, 2, 1)),
        cityVisit(id: 'visit-3', startedOn: DateTime(2026, 3, 1)),
        cityVisit(id: 'visit-4', startedOn: DateTime(2026, 4, 1)),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityVisit-visit-4')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-3')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsNothing);

    expect(find.byKey(const Key('cityVisitsViewAll')), findsOneWidget);
  });
  testWidgets('View all opens complete Visits history', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1'),
        cityVisit(id: 'visit-2'),
        cityVisit(id: 'visit-3'),
        cityVisit(id: 'visit-4'),
      ],
    );

    await pumpCityDetails(tester, repository);

    final viewAll = find.byKey(const Key('cityVisitsViewAll'));

    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    final visitsTab = tester.widget<Semantics>(
      find.byKey(const Key('cityTab-visits')),
    );

    expect(visitsTab.properties.selected, isTrue);

    for (final id in ['visit-1', 'visit-2', 'visit-3', 'visit-4']) {
      expect(find.byKey(Key('cityVisit-$id')), findsOneWidget);
    }
  });
  testWidgets('city statistics show real visit count', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1'),
        cityVisit(id: 'visit-2'),
        cityVisit(id: 'visit-3'),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityStatistics')), findsOneWidget);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('3')),
      findsOneWidget,
    );
  });
  testWidgets('city statistics show zero visits and zero associated trips', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(visits: []);

    await pumpCityDetails(tester, repository);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('cityLastVisited'))).data,
      '—',
    );
  });
  testWidgets('city statistics show latest visit date', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1', startedOn: DateTime(2024, 6, 10)),
        cityVisit(id: 'visit-2', startedOn: DateTime(2026, 10, 5)),
      ],
    );

    await pumpCityDetails(tester, repository);

    final lastVisited = tester.widget<Text>(
      find.byKey(const Key('cityLastVisited')),
    );

    expect(lastVisited.data, '5 Oct 2026');
  });
  testWidgets('city details show real associated trip count', (tester) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [
        cityTrip(id: 'trip-1', name: 'Portugal 2025'),
        cityTrip(id: 'trip-2', name: 'European Road Trip'),
      ],
    );

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    expect(tripsRepository.loadCalls, 1);
    expect(tripsRepository.receivedCityId, 2267057);

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('2')),
      findsOneWidget,
    );

    // Trips must not change the number of recorded visits.
    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('1')),
      findsOneWidget,
    );
  });
  testWidgets('Trips tab displays associated trips', (tester) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [
        cityTrip(
          id: 'trip-1',
          name: 'Portugal 2025',
          description: 'Summer holidays',
        ),
        cityTrip(id: 'trip-2', name: 'European Road Trip'),
      ],
    );

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    final tripsTab = find.byKey(const Key('cityTab-trips'));

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityAssociatedTrips')), findsOneWidget);

    expect(find.byKey(const Key('cityTrip-trip-1')), findsOneWidget);

    expect(find.byKey(const Key('cityTrip-trip-2')), findsOneWidget);

    expect(find.text('Portugal 2025'), findsOneWidget);
    expect(find.text('European Road Trip'), findsOneWidget);
    expect(find.text('Summer holidays'), findsOneWidget);
  });
  testWidgets('Trips tab shows empty state without associations', (
    tester,
  ) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository();

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    final tripsTab = find.byKey(const Key('cityTab-trips'));

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityTripsEmpty')), findsOneWidget);

    expect(find.text('No associated trips yet'), findsOneWidget);

    expect(find.byKey(const Key('cityTripsError')), findsNothing);

    // Existing visit history is unaffected.
    final visitsTab = find.byKey(const Key('cityTab-visits'));

    await tester.tap(visitsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);
  });
  testWidgets('Trips tab retries after loading failure', (tester) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(shouldFail: true);

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    final tripsTab = find.byKey(const Key('cityTab-trips'));

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityTripsError')), findsOneWidget);

    expect(find.text('Unable to load associated trips.'), findsOneWidget);

    // An unsuccessful request must not be presented as zero trips.
    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('—')),
      findsOneWidget,
    );

    // Simulate API recovery.
    tripsRepository.shouldFail = false;
    tripsRepository.trips = [cityTrip(id: 'trip-1', name: 'Portugal 2025')];

    final retryButton = find.byKey(const Key('cityTripsRetry'));

    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(tripsRepository.loadCalls, 2);

    expect(find.byKey(const Key('cityTripsError')), findsNothing);

    expect(find.byKey(const Key('cityTrip-trip-1')), findsOneWidget);

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('1')),
      findsOneWidget,
    );
  });
  testWidgets('associated trips do not automatically mark a city visited', (
    tester,
  ) async {
    final visitsRepository = FakeCityVisitsRepository(visits: []);

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [cityTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    expect(find.byKey(const Key('cityStatus-been')), findsNothing);

    expect(find.byKey(const Key('cityStatus-notVisited')), findsOneWidget);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('0')),
      findsOneWidget,
    );

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('1')),
      findsOneWidget,
    );
  });
  testWidgets('pull-to-refresh updates visits and associated trips', (
    tester,
  ) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [cityTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
    );

    expect(visitsRepository.loadCalls, 1);
    expect(tripsRepository.loadCalls, 1);

    visitsRepository.visits = [
      cityVisit(id: 'visit-1'),
      cityVisit(id: 'visit-2'),
    ];

    tripsRepository.trips = [
      cityTrip(id: 'trip-1', name: 'Portugal 2025'),
      cityTrip(id: 'trip-2', name: 'Portugal 2026'),
    ];

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    refreshIndicator.onRefresh();

    await tester.pumpAndSettle();

    expect(visitsRepository.loadCalls, 2);
    expect(tripsRepository.loadCalls, 2);

    final visitsStatistic = find.byKey(const Key('cityVisitsStatistic'));

    expect(
      find.descendant(of: visitsStatistic, matching: find.text('2')),
      findsOneWidget,
    );

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('2')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);
  });
  testWidgets('opens Trip Details from associated city trips', (tester) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [cityTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    final associationsRepository = FakeCityDetailsTripAssociationRepository();

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
      tripAssociationRepository: associationsRepository,
    );

    final tripsTab = find.byKey(const Key('cityTab-trips'));

    await tester.ensureVisible(tripsTab);
    await tester.tap(tripsTab);
    await tester.pumpAndSettle();

    final tripTile = find.byKey(const Key('cityTrip-trip-1'));

    expect(tripTile, findsOneWidget);

    await tester.ensureVisible(tripTile);
    await tester.tap(tripTile);
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsPage), findsOneWidget);

    expect(tripsRepository.detailsCalls, 1);
    expect(tripsRepository.receivedTripId, 'trip-1');

    expect(associationsRepository.countryLoadCalls, 1);
    expect(associationsRepository.cityLoadCalls, 1);

    expect(find.text('Portugal 2025'), findsWidgets);
  });
  testWidgets('refreshes city trips after returning from Trip Details', (
    tester,
  ) async {
    final visitsRepository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final tripsRepository = FakeCityDetailsTripRepository(
      trips: [cityTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    await pumpCityDetails(
      tester,
      visitsRepository,
      tripRepository: tripsRepository,
      tripAssociationRepository: FakeCityDetailsTripAssociationRepository(),
    );

    await tester.tap(find.byKey(const Key('cityTab-trips')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityTrip-trip-1')));
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsPage), findsOneWidget);

    expect(tripsRepository.loadCalls, 1);

    // Simulate an association being removed while Trip Details is open.
    tripsRepository.trips = [];

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsPage), findsNothing);

    expect(tripsRepository.loadCalls, 2);

    expect(find.byKey(const Key('cityTripsEmpty')), findsOneWidget);

    expect(find.byKey(const Key('cityTrip-trip-1')), findsNothing);

    final tripsStatistic = find.byKey(const Key('cityTripsStatistic'));

    expect(
      find.descendant(of: tripsStatistic, matching: find.text('0')),
      findsOneWidget,
    );
  });
}
