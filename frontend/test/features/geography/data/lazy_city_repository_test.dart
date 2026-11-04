import 'dart:async';

import 'package:beenaround/features/geography/data/city_repository_handle.dart';
import 'package:beenaround/features/geography/data/lazy_city_repository.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityRepository implements CityRepository {
  int searchCalls = 0;
  int countryCityCountCalls = 0;
  int resolveCalls = 0;
  List<int>? lastResolvedIds;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCalls++;

    return CitySearchResult(
      items: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    resolveCalls++;
    lastResolvedIds = List.unmodifiable(cityIds);

    return const [];
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    countryCityCountCalls++;

    return const [
      CountryCityCount(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityCount: 4,
      ),
      CountryCityCount(countryCode: 'FR', countryName: 'France', cityCount: 1),
    ];
  }
}

class FakeCityRepositoryHandle implements CityRepositoryHandle {
  FakeCityRepositoryHandle(this.repository);

  @override
  final CityRepository repository;

  int closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

void main() {
  group('LazyCityRepository', () {
    test('does not initialize before the first search', () async {
      var initializationCalls = 0;

      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      expect(initializationCalls, 0);

      await repository.close();

      expect(initializationCalls, 0);
      expect(handle.closeCalls, 0);
    });

    test('initializes on the first search', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      final result = await repository.search(query: 'Lisbon');

      expect(initializationCalls, 1);
      expect(fakeRepository.searchCalls, 1);
      expect(result.total, 0);

      await repository.close();
    });

    test('initializes on the first country city counts request', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      expect(initializationCalls, 0);

      final countries = await repository.listCountryCityCounts();

      expect(initializationCalls, 1);
      expect(fakeRepository.countryCityCountCalls, 1);
      expect(fakeRepository.searchCalls, 0);

      expect(countries.length, 2);
      expect(countries.first.countryCode, 'PT');
      expect(countries.first.cityCount, 4);

      await repository.close();

      expect(handle.closeCalls, 1);
    });

    test('reuses the initialized repository', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      await repository.search(query: 'Lisbon');
      await repository.search(query: 'Porto');
      await repository.search(countryCode: 'PT');

      expect(initializationCalls, 1);
      expect(fakeRepository.searchCalls, 3);

      await repository.close();
    });

    test('reuses initialization between searches and country counts', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      await repository.listCountryCityCounts();
      await repository.search(countryCode: 'PT');
      await repository.listCountryCityCounts();

      expect(initializationCalls, 1);
      expect(fakeRepository.countryCityCountCalls, 2);
      expect(fakeRepository.searchCalls, 1);

      await repository.close();

      expect(handle.closeCalls, 1);
    });

    test('shares initialization between concurrent searches', () async {
      var initializationCalls = 0;

      final completer = Completer<CityRepositoryHandle>();

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () {
          initializationCalls++;
          return completer.future;
        },
      );

      final first = repository.search(query: 'Lisbon');
      final second = repository.search(query: 'Porto');

      expect(initializationCalls, 1);

      completer.complete(handle);

      await Future.wait([first, second]);

      expect(initializationCalls, 1);
      expect(fakeRepository.searchCalls, 2);

      await repository.close();
    });

    test('shares initialization between search and country counts', () async {
      var initializationCalls = 0;

      final completer = Completer<CityRepositoryHandle>();

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () {
          initializationCalls++;
          return completer.future;
        },
      );

      final search = repository.search(query: 'Lisbon');
      final counts = repository.listCountryCityCounts();

      expect(initializationCalls, 1);

      completer.complete(handle);

      final results = await Future.wait<Object>([search, counts]);

      expect(initializationCalls, 1);
      expect(fakeRepository.searchCalls, 1);
      expect(fakeRepository.countryCityCountCalls, 1);

      expect(results[0], isA<CitySearchResult>());
      expect(results[1], isA<List<CountryCityCount>>());

      await repository.close();
    });

    test('retries after initialization failure', () async {
      var initializationCalls = 0;

      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;

          if (initializationCalls == 1) {
            throw StateError('Initialization failed.');
          }

          return handle;
        },
      );

      await expectLater(repository.search(query: 'Lisbon'), throwsStateError);

      final result = await repository.search(query: 'Lisbon');

      expect(result.total, 0);
      expect(initializationCalls, 2);

      await repository.close();
    });

    test('retries country counts after initialization failure', () async {
      var initializationCalls = 0;

      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;

          if (initializationCalls == 1) {
            throw StateError('Initialization failed.');
          }

          return handle;
        },
      );

      await expectLater(repository.listCountryCityCounts(), throwsStateError);

      final countries = await repository.listCountryCityCounts();

      expect(initializationCalls, 2);
      expect(countries.length, 2);

      await repository.close();
    });

    test('closes the initialized repository', () async {
      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(createHandle: () async => handle);

      await repository.search(query: 'Lisbon');

      await repository.close();

      expect(handle.closeCalls, 1);
    });

    test('closing twice does not close resources twice', () async {
      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(createHandle: () async => handle);

      await repository.search(query: 'Lisbon');

      await repository.close();
      await repository.close();

      expect(handle.closeCalls, 1);
    });

    test('closes resources if disposed during initialization', () async {
      final completer = Completer<CityRepositoryHandle>();

      final handle = FakeCityRepositoryHandle(FakeCityRepository());

      final repository = LazyCityRepository(
        createHandle: () => completer.future,
      );

      final search = repository.search(query: 'Lisbon');

      final closing = repository.close();

      completer.complete(handle);

      await expectLater(search, throwsStateError);

      await closing;

      expect(handle.closeCalls, 1);
    });

    test(
      'closes resources if disposed during country counts initialization',
      () async {
        final completer = Completer<CityRepositoryHandle>();

        final handle = FakeCityRepositoryHandle(FakeCityRepository());

        final repository = LazyCityRepository(
          createHandle: () => completer.future,
        );

        final counts = repository.listCountryCityCounts();

        final closing = repository.close();

        completer.complete(handle);

        await expectLater(counts, throwsStateError);

        await closing;

        expect(handle.closeCalls, 1);
      },
    );

    test('rejects searches after closing', () async {
      var initializationCalls = 0;

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return FakeCityRepositoryHandle(FakeCityRepository());
        },
      );

      await repository.close();

      await expectLater(repository.search(query: 'Lisbon'), throwsStateError);

      expect(initializationCalls, 0);
    });

    test('rejects country counts after closing', () async {
      var initializationCalls = 0;

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return FakeCityRepositoryHandle(FakeCityRepository());
        },
      );

      await repository.close();

      await expectLater(repository.listCountryCityCounts(), throwsStateError);

      expect(initializationCalls, 0);
    });

    test('forwards search parameters correctly', () async {
      final fakeRepository = _RecordingCityRepository();

      final repository = LazyCityRepository(
        createHandle: () async => FakeCityRepositoryHandle(fakeRepository),
      );

      await repository.search(
        query: 'Lisbon',
        countryCode: 'PT',
        sort: CitySort.name,
        limit: 15,
        offset: 30,
      );

      expect(fakeRepository.lastQuery, 'Lisbon');
      expect(fakeRepository.lastCountryCode, 'PT');
      expect(fakeRepository.lastSort, CitySort.name);
      expect(fakeRepository.lastLimit, 15);
      expect(fakeRepository.lastOffset, 30);

      await repository.close();
    });

    test('forwards default population sorting', () async {
      final fakeRepository = _RecordingCityRepository();

      final repository = LazyCityRepository(
        createHandle: () async => FakeCityRepositoryHandle(fakeRepository),
      );

      await repository.search(countryCode: 'PT');

      expect(fakeRepository.lastSort, CitySort.population);

      await repository.close();
    });

    test('forwards country city counts correctly', () async {
      final fakeRepository = _RecordingCityRepository();

      final repository = LazyCityRepository(
        createHandle: () async => FakeCityRepositoryHandle(fakeRepository),
      );

      final countries = await repository.listCountryCityCounts();

      expect(fakeRepository.countryCityCountCalls, 1);

      expect(countries, hasLength(1));
      expect(countries.single.countryCode, 'PT');
      expect(countries.single.countryName, 'Portugal');
      expect(countries.single.cityCount, 4);

      await repository.close();
    });
    test('initializes and delegates city ID resolution', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      expect(initializationCalls, 0);

      final cities = await repository.resolveByIds(cityIds: [4, 1, 3]);

      expect(cities, isEmpty);
      expect(initializationCalls, 1);
      expect(fakeRepository.resolveCalls, 1);
      expect(fakeRepository.lastResolvedIds, [4, 1, 3]);

      await repository.close();

      expect(handle.closeCalls, 1);
    });
    test('reuses the initialized handle for city resolution', () async {
      var initializationCalls = 0;

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () async {
          initializationCalls++;
          return handle;
        },
      );

      await repository.resolveByIds(cityIds: [1]);
      await repository.resolveByIds(cityIds: [2]);

      expect(initializationCalls, 1);
      expect(fakeRepository.resolveCalls, 2);
      expect(fakeRepository.lastResolvedIds, [2]);

      await repository.close();

      expect(handle.closeCalls, 1);
    });
    test('rejects city resolution after close', () async {
      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(createHandle: () async => handle);

      await repository.close();

      await expectLater(
        repository.resolveByIds(cityIds: [1]),
        throwsStateError,
      );

      expect(fakeRepository.resolveCalls, 0);
    });
    test('does not resolve cities if closed during initialization', () async {
      final completer = Completer<CityRepositoryHandle>();

      final fakeRepository = FakeCityRepository();
      final handle = FakeCityRepositoryHandle(fakeRepository);

      final repository = LazyCityRepository(
        createHandle: () => completer.future,
      );

      final pendingResolution = repository.resolveByIds(cityIds: [1, 2]);

      final closeFuture = repository.close();

      completer.complete(handle);

      await expectLater(pendingResolution, throwsStateError);

      await closeFuture;

      expect(fakeRepository.resolveCalls, 0);
      expect(handle.closeCalls, 1);
    });
  });
}

class _RecordingCityRepository implements CityRepository {
  String? lastQuery;
  String? lastCountryCode;
  CitySort? lastSort;
  int? lastLimit;
  int? lastOffset;

  int countryCityCountCalls = 0;
  int resolveCalls = 0;
  List<int>? lastResolvedIds;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    lastQuery = query;
    lastCountryCode = countryCode;
    lastSort = sort;
    lastLimit = limit;
    lastOffset = offset;

    return CitySearchResult(
      items: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    resolveCalls++;
    lastResolvedIds = List.unmodifiable(cityIds);

    return const [];
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    countryCityCountCalls++;

    return const [
      CountryCityCount(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityCount: 4,
      ),
    ];
  }
}
