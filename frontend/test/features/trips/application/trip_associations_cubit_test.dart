import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';

import 'package:flutter_test/flutter_test.dart';

const tripId = 'trip-1';

CountryVisit sampleCountryVisit({String id = 'country-visit-1'}) {
  return CountryVisit(
    id: id,
    countryCode: 'JP',
    startedOn: DateTime(2027, 4, 10),
    endedOn: DateTime(2027, 4, 25),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit sampleCityVisit({String id = 'city-visit-1'}) {
  return CityVisit(
    id: id,
    cityId: 1850147,
    cityName: 'Tokyo',
    countryCode: 'JP',
    countryName: 'Japan',
    startedOn: DateTime(2027, 4, 10),
    endedOn: DateTime(2027, 4, 15),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class FakeTripAssociationRepository implements TripAssociationRepository {
  List<CountryVisit> countries = [];
  List<CityVisit> cities = [];

  int countryLoads = 0;
  int cityLoads = 0;

  int addCountryCalls = 0;
  int addCityCalls = 0;

  int removeCountryCalls = 0;
  int removeCityCalls = 0;

  Future<List<CountryVisit>> Function()? onGetCountries;
  Future<List<CityVisit>> Function()? onGetCities;

  Future<void> Function(String visitId)? onAddCountry;
  Future<void> Function(String visitId)? onAddCity;

  Future<void> Function(String visitId)? onRemoveCountry;
  Future<void> Function(String visitId)? onRemoveCity;

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) {
    countryLoads++;

    return onGetCountries?.call() ?? Future.value(countries);
  }

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) {
    cityLoads++;

    return onGetCities?.call() ?? Future.value(cities);
  }

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) {
    addCountryCalls++;

    return onAddCountry?.call(visitId) ?? Future.value();
  }

  @override
  Future<void> addCityVisit({required String tripId, required String visitId}) {
    addCityCalls++;

    return onAddCity?.call(visitId) ?? Future.value();
  }

  @override
  Future<void> removeCountryVisit({
    required String tripId,
    required String visitId,
  }) {
    removeCountryCalls++;

    return onRemoveCountry?.call(visitId) ?? Future.value();
  }

  @override
  Future<void> removeCityVisit({
    required String tripId,
    required String visitId,
  }) {
    removeCityCalls++;

    return onRemoveCity?.call(visitId) ?? Future.value();
  }
}

void main() {
  late FakeTripAssociationRepository repository;
  late TripAssociationsCubit cubit;

  setUp(() {
    repository = FakeTripAssociationRepository();

    cubit = TripAssociationsCubit(repository: repository, tripId: tripId);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state has no associated visits', () {
    expect(cubit.state.hasLoaded, isFalse);
    expect(cubit.state.countryVisits, isEmpty);
    expect(cubit.state.cityVisits, isEmpty);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.isMutating, isFalse);
  });

  test('loads country and city visits', () async {
    repository.countries = [sampleCountryVisit()];

    repository.cities = [sampleCityVisit()];

    await cubit.load();

    expect(cubit.state.hasLoaded, isTrue);
    expect(cubit.state.countryVisits, hasLength(1));
    expect(cubit.state.cityVisits, hasLength(1));

    expect(repository.countryLoads, 1);
    expect(repository.cityLoads, 1);
  });

  test('empty responses count as successful loading', () async {
    await cubit.load();

    expect(cubit.state.hasLoaded, isTrue);
    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.isReady, isTrue);
  });

  test('refresh retrieves updated associations', () async {
    await cubit.load();

    repository.countries = [sampleCountryVisit()];

    await cubit.refresh();

    expect(cubit.state.countryVisits, hasLength(1));
    expect(repository.countryLoads, 2);
  });

  test('loading errors preserve previously loaded data', () async {
    repository.countries = [sampleCountryVisit()];

    await cubit.load();

    repository.onGetCountries = () async {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Server unavailable.',
        statusCode: 500,
      );
    };

    await cubit.refresh();

    expect(cubit.state.hasLoaded, isTrue);
    expect(cubit.state.countryVisits, hasLength(1));
    expect(cubit.state.loadError, 'Server unavailable.');
  });

  test('adding a country visit refreshes associations', () async {
    repository.onAddCountry = (visitId) async {
      expect(visitId, 'country-visit-1');

      repository.countries = [sampleCountryVisit()];
    };

    await cubit.addCountryVisit(visitId: 'country-visit-1');

    expect(repository.addCountryCalls, 1);
    expect(cubit.state.countryVisits, hasLength(1));
    expect(cubit.state.isMutating, isFalse);
  });

  test('adding a city visit refreshes associations', () async {
    repository.onAddCity = (visitId) async {
      repository.cities = [sampleCityVisit(id: visitId)];
    };

    await cubit.addCityVisit(visitId: 'city-visit-1');

    expect(repository.addCityCalls, 1);
    expect(cubit.state.cityVisits.single.id, 'city-visit-1');
  });

  test('removing a country visit refreshes associations', () async {
    repository.countries = [sampleCountryVisit()];

    await cubit.load();

    repository.onRemoveCountry = (_) async {
      repository.countries = [];
    };

    await cubit.removeCountryVisit(visitId: 'country-visit-1');

    expect(repository.removeCountryCalls, 1);
    expect(cubit.state.countryVisits, isEmpty);
  });

  test('removing a city visit refreshes associations', () async {
    repository.cities = [sampleCityVisit()];

    await cubit.load();

    repository.onRemoveCity = (_) async {
      repository.cities = [];
    };

    await cubit.removeCityVisit(visitId: 'city-visit-1');

    expect(repository.removeCityCalls, 1);
    expect(cubit.state.cityVisits, isEmpty);
  });

  test('mutation errors preserve existing associations', () async {
    repository.countries = [sampleCountryVisit()];

    await cubit.load();

    repository.onRemoveCountry = (_) async {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Association not found.',
        statusCode: 404,
      );
    };

    await cubit.removeCountryVisit(visitId: 'country-visit-1');

    expect(cubit.state.countryVisits, hasLength(1));

    expect(cubit.state.mutationError, 'Association not found.');

    expect(cubit.state.isMutating, isFalse);
  });

  test('prevents duplicate mutations', () async {
    final pending = Completer<void>();

    repository.onAddCountry = (_) => pending.future;

    final first = cubit.addCountryVisit(visitId: 'country-visit-1');

    final second = cubit.addCountryVisit(visitId: 'country-visit-1');

    expect(repository.addCountryCalls, 1);

    pending.complete();

    await Future.wait([first, second]);

    expect(repository.addCountryCalls, 1);
    expect(cubit.state.isMutating, isFalse);
  });

  test('stale loading responses cannot replace newer data', () async {
    final firstCountries = Completer<List<CountryVisit>>();
    final firstCities = Completer<List<CityVisit>>();

    var countryCalls = 0;
    var cityCalls = 0;

    repository.onGetCountries = () {
      countryCalls++;

      return countryCalls == 1
          ? firstCountries.future
          : Future.value([sampleCountryVisit(id: 'new-country')]);
    };

    repository.onGetCities = () {
      cityCalls++;

      return cityCalls == 1 ? firstCities.future : Future.value([]);
    };

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    await secondLoad;

    firstCountries.complete([sampleCountryVisit(id: 'old-country')]);

    firstCities.complete([]);

    await firstLoad;

    expect(cubit.state.countryVisits.single.id, 'new-country');
  });

  test('closing during loading prevents further emissions', () async {
    final pending = Completer<List<CountryVisit>>();

    repository.onGetCountries = () => pending.future;

    final loading = cubit.load();

    await cubit.close();

    pending.complete([]);

    await loading;

    expect(cubit.isClosed, isTrue);
  });
  test(
    'successful association followed by failed refresh preserves data',
    () async {
      final existingVisit = sampleCountryVisit(id: 'existing-country');

      final newVisit = sampleCountryVisit(id: 'new-country');

      repository.countries = [existingVisit];

      // Load the initial associations successfully.
      await cubit.load();

      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.countryVisits, hasLength(1));

      // Simulate a successful POST.
      repository.onAddCountry = (visitId) async {
        expect(visitId, newVisit.id);

        // The backend now contains both associations.
        repository.countries = [existingVisit, newVisit];
      };

      // Simulate a GET failure after the successful POST.
      repository.onGetCountries = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Unable to refresh Trip visits.',
          statusCode: 500,
        );
      };

      await cubit.addCountryVisit(visitId: newVisit.id);

      // The POST was executed successfully.
      expect(repository.addCountryCalls, 1);

      // Previously loaded data must remain available.
      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.countryVisits, hasLength(1));

      expect(cubit.state.countryVisits.single.id, existingVisit.id);

      // The failure happened during refresh, not during mutation.
      expect(cubit.state.mutationError, isNull);

      expect(cubit.state.loadError, 'Unable to refresh Trip visits.');

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isMutating, isFalse);

      // Restore normal backend responses.
      repository.onGetCountries = null;

      await cubit.refresh();

      expect(cubit.state.loadError, isNull);

      // Both associations now appear.
      expect(cubit.state.countryVisits, hasLength(2));

      expect(cubit.state.countryVisits.map((visit) => visit.id).toSet(), {
        'existing-country',
        'new-country',
      });
    },
  );
  group('batch associations', () {
    test('adds multiple country visits and refreshes once', () async {
      final addedIds = <String>[];

      repository.onAddCountry = (visitId) async {
        addedIds.add(visitId);

        repository.countries = [
          ...repository.countries,
          sampleCountryVisit(id: visitId),
        ];
      };

      await cubit.addCountryVisits(
        visitIds: ['country-1', 'country-2', 'country-3'],
      );

      expect(addedIds, ['country-1', 'country-2', 'country-3']);

      expect(repository.addCountryCalls, 3);

      // A single refresh after the entire batch.
      expect(repository.countryLoads, 1);
      expect(repository.cityLoads, 1);

      expect(cubit.state.countryVisits, hasLength(3));
      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.isMutating, isFalse);
      expect(cubit.state.mutationError, isNull);
    });
    test('adds multiple city visits and refreshes once', () async {
      repository.onAddCity = (visitId) async {
        repository.cities = [
          ...repository.cities,
          sampleCityVisit(id: visitId),
        ];
      };

      await cubit.addCityVisits(visitIds: ['city-1', 'city-2']);

      expect(repository.addCityCalls, 2);

      expect(repository.countryLoads, 1);
      expect(repository.cityLoads, 1);

      expect(cubit.state.cityVisits.map((visit) => visit.id).toList(), [
        'city-1',
        'city-2',
      ]);

      expect(cubit.state.mutationError, isNull);
      expect(cubit.state.isMutating, isFalse);
    });
    test('deduplicates visit IDs while preserving selection order', () async {
      final addedIds = <String>[];

      repository.onAddCountry = (visitId) async {
        addedIds.add(visitId);
      };

      await cubit.addCountryVisits(
        visitIds: [
          'country-2',
          'country-1',
          'country-2',
          'country-3',
          'country-1',
        ],
      );

      expect(addedIds, ['country-2', 'country-1', 'country-3']);

      expect(repository.addCountryCalls, 3);
    });
    test('empty batch performs no requests or refresh', () async {
      await cubit.addCountryVisits(visitIds: []);
      await cubit.addCityVisits(visitIds: []);

      expect(repository.addCountryCalls, 0);
      expect(repository.addCityCalls, 0);

      expect(repository.countryLoads, 0);
      expect(repository.cityLoads, 0);

      expect(cubit.state.isMutating, isFalse);
    });
    test('partial failure preserves successful associations', () async {
      final attemptedIds = <String>[];

      repository.onAddCountry = (visitId) async {
        attemptedIds.add(visitId);

        if (visitId == 'country-3') {
          throw const ApiException(
            type: ApiErrorType.server,
            message: 'Unable to associate this visit.',
            statusCode: 500,
          );
        }

        repository.countries = [
          ...repository.countries,
          sampleCountryVisit(id: visitId),
        ];
      };

      await cubit.addCountryVisits(
        visitIds: ['country-1', 'country-2', 'country-3', 'country-4'],
      );

      // The batch stops after the first failure.
      expect(attemptedIds, ['country-1', 'country-2', 'country-3']);

      expect(repository.addCountryCalls, 3);

      // Successful associations remain available.
      expect(cubit.state.countryVisits.map((visit) => visit.id).toSet(), {
        'country-1',
        'country-2',
      });

      expect(cubit.state.mutationError, contains('Added 2 of 4 visits'));

      expect(
        cubit.state.mutationError,
        contains('Unable to associate this visit.'),
      );

      expect(repository.countryLoads, 1);
      expect(repository.cityLoads, 1);

      expect(cubit.state.isMutating, isFalse);
    });
    test('does not start another mutation during a batch', () async {
      final pending = Completer<void>();

      repository.onAddCountry = (_) => pending.future;

      final batch = cubit.addCountryVisits(visitIds: ['country-1']);

      expect(cubit.state.isMutating, isTrue);

      // Must not execute while the batch is active.
      await cubit.addCountryVisit(visitId: 'country-2');

      await cubit.addCityVisits(visitIds: ['city-1']);

      expect(repository.addCountryCalls, 1);
      expect(repository.addCityCalls, 0);

      pending.complete();

      await batch;

      expect(cubit.state.isMutating, isFalse);
    });
    test('closing during a batch prevents remaining associations', () async {
      final pending = Completer<void>();

      repository.onAddCountry = (_) => pending.future;

      final batch = cubit.addCountryVisits(
        visitIds: ['country-1', 'country-2'],
      );

      expect(repository.addCountryCalls, 1);

      await cubit.close();

      pending.complete();

      await batch;

      expect(repository.addCountryCalls, 1);
      expect(repository.countryLoads, 0);
      expect(repository.cityLoads, 0);
      expect(cubit.isClosed, isTrue);
    });
    test('batch refresh failure preserves existing data', () async {
      repository.countries = [sampleCountryVisit(id: 'existing-country')];

      await cubit.load();

      repository.onAddCountry = (visitId) async {
        repository.countries = [
          ...repository.countries,
          sampleCountryVisit(id: visitId),
        ];
      };

      repository.onGetCountries = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Unable to refresh associations.',
          statusCode: 500,
        );
      };

      await cubit.addCountryVisits(visitIds: ['new-country']);

      expect(repository.addCountryCalls, 1);

      expect(cubit.state.countryVisits.map((visit) => visit.id).toList(), [
        'existing-country',
      ]);

      expect(cubit.state.mutationError, isNull);

      expect(cubit.state.loadError, 'Unable to refresh associations.');

      expect(cubit.state.isMutating, isFalse);
    });
  });
}
