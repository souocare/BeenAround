import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/application/explore_cities_cubit.dart';
import 'package:beenaround/features/explore/application/explore_cities_state.dart';
import 'package:beenaround/features/explore/application/visited_cities_state.dart';

import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';

import 'package:beenaround/features/residences/application/residences_state.dart';
import 'package:beenaround/features/residences/domain/residence.dart';

import 'package:beenaround/features/wishlist/application/wishlist_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';

import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// Fixtures
// -----------------------------------------------------------------------------

final timestamp = DateTime(2026, 11, 4);

City makeCity(int id) {
  return City(
    id: id,
    name: 'City $id',
    asciiName: 'City $id',
    countryCode: 'PT',
    countryName: 'Portugal',
    latitude: 38.72,
    longitude: -9.13,
    population: 1000,
    featureCode: 'PPL',
  );
}

CityVisit makeVisit(int cityId, {String? id}) {
  return CityVisit(
    id: id ?? 'visit-$cityId',
    cityId: cityId,
    cityName: 'City $cityId',
    countryCode: 'PT',
    countryName: 'Portugal',
    startedOn: null,
    endedOn: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Residence makeResidence(int cityId, {String? id}) {
  return Residence(
    id: id ?? 'residence-$cityId',
    countryCode: 'PT',
    cityId: cityId,
    startedOn: DateTime(2020, 1),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2022, 12),
    endedOnPrecision: VisitDatePrecision.month,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

WishlistEntry makeWish(int cityId, {String? id}) {
  return WishlistEntry(
    id: id ?? 'wish-$cityId',
    countryCode: null,
    cityId: cityId,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

VisitedCitiesState visitedState(
  List<CityVisit> visits, {
  VisitedCitiesPhase phase = VisitedCitiesPhase.ready,
}) {
  return VisitedCitiesState(phase: phase, visits: visits);
}

ResidencesState residencesState(
  List<Residence> residences, {
  ResidencesPhase phase = ResidencesPhase.ready,
}) {
  return ResidencesState(phase: phase, residences: residences);
}

WishlistState wishlistState(
  List<WishlistEntry> entries, {
  WishlistPhase phase = WishlistPhase.ready,
}) {
  return WishlistState(phase: phase, entries: entries);
}

// -----------------------------------------------------------------------------
// Fake repository
// -----------------------------------------------------------------------------

class FakeCityRepository implements CityRepository {
  final List<List<int>> requestedBatches = [];

  Future<List<City>> Function(List<int> ids)? onResolve;

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    requestedBatches.add(List.unmodifiable(cityIds));

    final handler = onResolve;

    if (handler != null) {
      return handler(cityIds);
    }

    return cityIds.map(makeCity).toList(growable: false);
  }

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() {
    throw UnimplementedError();
  }
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

void main() {
  group('ExploreCitiesCubit', () {
    test('starts with an empty initial state', () {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      expect(cubit.state.phase, ExploreCitiesPhase.initial);
      expect(cubit.state.cities, isEmpty);
      expect(repository.requestedBatches, isEmpty);
    });

    test('returns ready without requests when no cities exist', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cities, isEmpty);
      expect(repository.requestedBatches, isEmpty);
    });

    test('resolves and aggregates explicit city visits', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          makeVisit(100, id: 'visit-1'),
          makeVisit(100, id: 'visit-2'),
        ]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 1);
      expect(cubit.state.beenCityCount, 1);
      expect(cubit.state.livedCityCount, 0);
      expect(cubit.state.wishCityCount, 0);

      final entry = cubit.state.cities.single;

      expect(entry.city.id, 100);
      expect(entry.summary.visitCount, 2);
      expect(entry.summary.hasMultipleVisits, isTrue);

      expect(repository.requestedBatches, [
        [100],
      ]);
    });

    test('includes cities that have only a residence', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([]),
        residences: residencesState([makeResidence(200)]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 1);

      final entry = cubit.state.cities.single;

      expect(entry.city.id, 200);
      expect(entry.summary.hasBeen, isFalse);
      expect(entry.summary.hasLived, isTrue);
      expect(entry.summary.isWishlisted, isFalse);
    });

    test('includes cities that have only a wishlist entry', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([]),
        residences: residencesState([]),
        wishlist: wishlistState([makeWish(300)]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 1);

      final entry = cubit.state.cities.single;

      expect(entry.city.id, 300);
      expect(entry.summary.hasBeen, isFalse);
      expect(entry.summary.hasLived, isFalse);
      expect(entry.summary.isWishlisted, isTrue);
    });

    test('combines Been, Lived and Wish without duplicates', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          makeVisit(100, id: 'visit-1'),
          makeVisit(100, id: 'visit-2'),
        ]),
        residences: residencesState([makeResidence(100)]),
        wishlist: wishlistState([makeWish(100)]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);

      expect(cubit.state.cityCount, 1);
      expect(cubit.state.beenCityCount, 1);
      expect(cubit.state.livedCityCount, 1);
      expect(cubit.state.wishCityCount, 1);

      final summary = cubit.state.cities.single.summary;

      expect(summary.visitCount, 2);
      expect(summary.residenceCount, 1);
      expect(summary.isWishlisted, isTrue);

      expect(repository.requestedBatches, [
        [100],
      ]);
    });

    test('resolves exactly 200 cities in one batch', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          for (var id = 1; id <= 200; id++) makeVisit(id),
        ]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 200);

      expect(repository.requestedBatches, hasLength(1));
      expect(repository.requestedBatches.single, hasLength(200));
    });

    test('resolves 201 cities in two batches', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          for (var id = 1; id <= 201; id++) makeVisit(id),
        ]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 201);

      expect(repository.requestedBatches, hasLength(2));
      expect(repository.requestedBatches[0], hasLength(200));
      expect(repository.requestedBatches[1], [201]);
    });

    test('resolves 450 cities without truncation', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          for (var id = 1; id <= 450; id++) makeVisit(id),
        ]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 450);
      expect(cubit.state.beenCityCount, 450);

      expect(repository.requestedBatches, hasLength(3));

      expect(repository.requestedBatches.map((batch) => batch.length), [
        200,
        200,
        50,
      ]);

      final resolvedIds = repository.requestedBatches
          .expand((batch) => batch)
          .toSet();

      expect(resolvedIds.length, 450);
      expect(resolvedIds.contains(450), isTrue);
    });

    test('fails without publishing partial results', () async {
      final repository = FakeCityRepository();

      var calls = 0;

      repository.onResolve = (ids) async {
        calls++;

        if (calls == 2) {
          throw StateError('Catalog unavailable');
        }

        return ids.map(makeCity).toList();
      };

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([
          for (var id = 1; id <= 201; id++) makeVisit(id),
        ]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(calls, 2);
      expect(cubit.state.phase, ExploreCitiesPhase.failure);
      expect(cubit.state.cities, isEmpty);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('fails when referenced catalog cities are missing', () async {
      final repository = FakeCityRepository()..onResolve = (_) async => [];

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.failure);
      expect(cubit.state.cities, isEmpty);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('ignores stale responses from older loads', () async {
      final firstRequest = Completer<List<City>>();
      final secondRequest = Completer<List<City>>();

      final repository = FakeCityRepository();

      var calls = 0;

      repository.onResolve = (_) {
        calls++;

        return calls == 1 ? firstRequest.future : secondRequest.future;
      };

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      final firstLoad = cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      final secondLoad = cubit.load(
        visitedCities: visitedState([makeVisit(200)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(calls, 2);

      // Newer request finishes first.
      secondRequest.complete([makeCity(200)]);

      await secondLoad;

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cities.single.city.id, 200);

      // Older request finishes afterwards.
      firstRequest.complete([makeCity(100)]);

      await firstLoad;

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cities.single.city.id, 200);
    });

    test('ignores stale failures from older loads', () async {
      final firstRequest = Completer<List<City>>();
      final secondRequest = Completer<List<City>>();

      final repository = FakeCityRepository();

      var calls = 0;

      repository.onResolve = (_) {
        calls++;

        return calls == 1 ? firstRequest.future : secondRequest.future;
      };

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      final firstLoad = cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      final secondLoad = cubit.load(
        visitedCities: visitedState([makeVisit(200)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      secondRequest.complete([makeCity(200)]);

      await secondLoad;

      firstRequest.completeError(StateError('Outdated catalog failure'));

      await firstLoad;

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cities.single.city.id, 200);
      expect(cubit.state.errorMessage, isNull);
    });

    test('does not aggregate incomplete source states', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([], phase: ResidencesPhase.loading),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.initial);
      expect(cubit.state.cities, isEmpty);

      expect(repository.requestedBatches, isEmpty);
    });

    test(
      'invalidates pending requests when sources become incomplete',
      () async {
        final pendingRequest = Completer<List<City>>();
        final repository = FakeCityRepository()
          ..onResolve = (_) => pendingRequest.future;

        final cubit = ExploreCitiesCubit(cityRepository: repository);

        addTearDown(cubit.close);

        final pendingLoad = cubit.load(
          visitedCities: visitedState([makeVisit(100)]),
          residences: residencesState([]),
          wishlist: wishlistState([]),
        );

        await cubit.load(
          visitedCities: visitedState([], phase: VisitedCitiesPhase.loading),
          residences: residencesState([]),
          wishlist: wishlistState([]),
        );

        pendingRequest.complete([makeCity(100)]);
        await pendingLoad;

        expect(cubit.state.phase, ExploreCitiesPhase.initial);
        expect(cubit.state.cities, isEmpty);
      },
    );

    test('preserves previous results when refresh fails', () async {
      final repository = FakeCityRepository();

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      addTearDown(cubit.close);

      await cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.ready);
      expect(cubit.state.cityCount, 1);

      repository.onResolve = (_) async {
        throw StateError('Network unavailable');
      };

      await cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      expect(cubit.state.phase, ExploreCitiesPhase.failure);
      expect(cubit.state.cityCount, 1);
      expect(cubit.state.cities.single.city.id, 100);
    });

    test('does not publish results after being closed', () async {
      final pendingRequest = Completer<List<City>>();

      final repository = FakeCityRepository()
        ..onResolve = (_) => pendingRequest.future;

      final cubit = ExploreCitiesCubit(cityRepository: repository);

      final pendingLoad = cubit.load(
        visitedCities: visitedState([makeVisit(100)]),
        residences: residencesState([]),
        wishlist: wishlistState([]),
      );

      await cubit.close();

      pendingRequest.complete([makeCity(100)]);

      await pendingLoad;

      expect(cubit.isClosed, isTrue);
    });
  });
}
