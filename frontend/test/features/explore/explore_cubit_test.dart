import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/application/explore_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({this.countries = const [], this.visits = const []});

  List<Country> countries;
  List<CountryVisit> visits;

  int countriesCalls = 0;
  int visitsCalls = 0;

  Future<List<Country>> Function()? countriesHandler;
  Future<List<CountryVisit>> Function()? visitsHandler;

  @override
  Future<List<Country>> getCountries() {
    countriesCalls++;

    if (countriesHandler != null) {
      return countriesHandler!();
    }

    return Future.value(countries);
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() {
    visitsCalls++;

    if (visitsHandler != null) {
      return visitsHandler!();
    }

    return Future.value(visits);
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
}

const portugal = Country(code: 'PT', name: 'Portugal', alpha3Code: 'PRT');

const spain = Country(code: 'ES', name: 'Spain', alpha3Code: 'ESP');

CountryVisit createVisit({required String id, required String countryCode}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

void main() {
  group('ExploreCubit', () {
    test('starts in initial state', () {
      final cubit = ExploreCubit(repository: FakeCountriesRepository());

      expect(cubit.state.phase, ExplorePhase.initial);
      expect(cubit.state.countries, isEmpty);
      expect(cubit.state.visits, isEmpty);

      cubit.close();
    });

    test('loads countries and visits', () async {
      final repository = FakeCountriesRepository(
        countries: [portugal, spain],
        visits: [
          createVisit(id: '1', countryCode: 'PT'),
          createVisit(id: '2', countryCode: 'PT'),
          createVisit(id: '3', countryCode: 'ES'),
        ],
      );

      final cubit = ExploreCubit(repository: repository);

      final phases = <ExplorePhase>[];

      final subscription = cubit.stream.listen(
        (state) => phases.add(state.phase),
      );

      await cubit.load();

      await pumpEventQueue();

      expect(phases, [ExplorePhase.loading, ExplorePhase.ready]);

      expect(cubit.state.visitedCountryCount, 2);
      expect(cubit.state.totalVisits, 3);
      expect(cubit.state.totalCountries, 2);
      expect(cubit.state.unvisitedCountryCount, 0);

      expect(cubit.state.isCountryVisited('PT'), isTrue);
      expect(cubit.state.visitsForCountry('PT'), hasLength(2));

      expect(repository.countriesCalls, 1);
      expect(repository.visitsCalls, 1);

      await subscription.cancel();
      await cubit.close();
    });

    test('supports countries without visits', () async {
      final cubit = ExploreCubit(
        repository: FakeCountriesRepository(countries: [portugal, spain]),
      );

      await cubit.load();

      expect(cubit.state.phase, ExplorePhase.ready);
      expect(cubit.state.visitedCountryCount, 0);
      expect(cubit.state.totalVisits, 0);
      expect(cubit.state.unvisitedCountryCount, 2);

      await cubit.close();
    });

    test('maps API errors to failure state', () async {
      final repository = FakeCountriesRepository();

      repository.countriesHandler = () async {
        throw const ApiException(
          type: ApiErrorType.connection,
          message: 'Unable to connect to the server.',
        );
      };

      final cubit = ExploreCubit(repository: repository);

      await cubit.load();

      expect(cubit.state.phase, ExplorePhase.failure);
      expect(cubit.state.errorMessage, 'Unable to connect to the server.');

      await cubit.close();
    });

    test('maps unexpected errors to generic message', () async {
      final repository = FakeCountriesRepository();

      repository.visitsHandler = () async {
        throw const FormatException('Invalid response');
      };

      final cubit = ExploreCubit(repository: repository);

      await cubit.load();

      expect(cubit.state.phase, ExplorePhase.failure);
      expect(cubit.state.errorMessage, 'Unable to load your travel history.');

      await cubit.close();
    });

    test('refresh reloads both resources', () async {
      final repository = FakeCountriesRepository(countries: [portugal, spain]);

      final cubit = ExploreCubit(repository: repository);

      await cubit.load();

      expect(cubit.state.totalVisits, 0);

      repository.visits = [createVisit(id: '1', countryCode: 'PT')];

      await cubit.refresh();

      expect(cubit.state.totalVisits, 1);
      expect(cubit.state.visitedCountryCount, 1);
      expect(repository.countriesCalls, 2);
      expect(repository.visitsCalls, 2);

      await cubit.close();
    });

    test('keeps previous data while refreshing', () async {
      final repository = FakeCountriesRepository(
        countries: [portugal],
        visits: [createVisit(id: '1', countryCode: 'PT')],
      );

      final cubit = ExploreCubit(repository: repository);

      await cubit.load();

      final pending = Completer<List<Country>>();

      repository.countriesHandler = () => pending.future;

      final refresh = cubit.refresh();

      expect(cubit.state.phase, ExplorePhase.loading);
      expect(cubit.state.totalVisits, 1);
      expect(cubit.state.visitedCountryCount, 1);

      pending.complete([portugal, spain]);

      await refresh;

      expect(cubit.state.phase, ExplorePhase.ready);
      expect(cubit.state.totalCountries, 2);

      await cubit.close();
    });

    test('ignores older requests', () async {
      final repository = FakeCountriesRepository();

      final first = Completer<List<Country>>();
      var calls = 0;

      repository.countriesHandler = () {
        calls++;

        if (calls == 1) return first.future;

        return Future.value([spain]);
      };

      final cubit = ExploreCubit(repository: repository);

      final olderLoad = cubit.load();

      await cubit.load();

      expect(cubit.state.phase, ExplorePhase.ready);
      expect(cubit.state.countries.single.code, 'ES');

      first.complete([portugal]);

      await olderLoad;

      expect(cubit.state.countries.single.code, 'ES');

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final pending = Completer<List<Country>>();

      final repository = FakeCountriesRepository()
        ..countriesHandler = () => pending.future;

      final cubit = ExploreCubit(repository: repository);

      final load = cubit.load();

      await cubit.close();

      pending.complete([portugal]);

      await load;

      expect(cubit.isClosed, isTrue);
    });
  });
}
