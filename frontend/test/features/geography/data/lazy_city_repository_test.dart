import 'dart:async';

import 'package:beenaround/features/geography/data/city_repository_handle.dart';
import 'package:beenaround/features/geography/data/lazy_city_repository.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityRepository implements CityRepository {
  int searchCalls = 0;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
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

    test('forwards search parameters correctly', () async {
      final fakeRepository = _RecordingCityRepository();

      final repository = LazyCityRepository(
        createHandle: () async => FakeCityRepositoryHandle(fakeRepository),
      );

      await repository.search(
        query: 'Lisbon',
        countryCode: 'PT',
        limit: 15,
        offset: 30,
      );

      expect(fakeRepository.lastQuery, 'Lisbon');
      expect(fakeRepository.lastCountryCode, 'PT');
      expect(fakeRepository.lastLimit, 15);
      expect(fakeRepository.lastOffset, 30);

      await repository.close();
    });
  });
}

class _RecordingCityRepository implements CityRepository {
  String? lastQuery;
  String? lastCountryCode;
  int? lastLimit;
  int? lastOffset;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    int limit = 20,
    int offset = 0,
  }) async {
    lastQuery = query;
    lastCountryCode = countryCode;
    lastLimit = limit;
    lastOffset = offset;

    return CitySearchResult(
      items: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }
}
