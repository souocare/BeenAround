import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_search_cubit.dart';
import 'package:beenaround/features/map/application/map_search_results.dart';
import 'package:beenaround/features/map/application/map_search_state.dart';

void main() {
  group('MapSearchCubit', () {
    test('starts in idle state', () async {
      final cubit = MapSearchCubit(search: (_) async => MapSearchResults());

      expect(cubit.state.phase, MapSearchPhase.idle);
      expect(cubit.state.query, '');
      expect(cubit.state.results.hasResults, isFalse);

      await cubit.close();
    });

    testWidgets('debounces query changes', (tester) async {
      final queries = <String>[];

      final cubit = MapSearchCubit(
        search: (query) async {
          queries.add(query);
          return MapSearchResults();
        },
      );

      cubit.queryChanged('Lis');

      expect(cubit.state.phase, MapSearchPhase.waiting);

      await tester.pump(const Duration(milliseconds: 200));

      cubit.queryChanged('Lisbon');

      await tester.pump(const Duration(milliseconds: 200));

      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(queries, ['Lisbon']);
      expect(cubit.state.phase, MapSearchPhase.ready);

      await cubit.close();
    });

    testWidgets('normalizes query before searching', (tester) async {
      String? receivedQuery;

      final cubit = MapSearchCubit(
        search: (query) async {
          receivedQuery = query;
          return MapSearchResults();
        },
      );

      cubit.queryChanged('  Madrid  ');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(receivedQuery, 'Madrid');
      expect(cubit.state.query, '  Madrid  ');

      await cubit.close();
    });

    testWidgets('ignores outdated search responses', (tester) async {
      final oldRequest = Completer<MapSearchResults>();
      final newRequest = Completer<MapSearchResults>();

      final cubit = MapSearchCubit(
        search: (query) {
          if (query == 'Lisbon') {
            return oldRequest.future;
          }

          return newRequest.future;
        },
      );

      cubit.queryChanged('Lisbon');

      await tester.pump(const Duration(milliseconds: 300));

      expect(cubit.state.phase, MapSearchPhase.loading);

      cubit.queryChanged('Madrid');

      await tester.pump(const Duration(milliseconds: 300));

      expect(cubit.state.phase, MapSearchPhase.loading);

      newRequest.complete(MapSearchResults());

      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.ready);
      expect(cubit.state.query, 'Madrid');

      oldRequest.complete(
        MapSearchResults(
          failedCategories: {
            MapSearchCategory.countries,
            MapSearchCategory.cities,
            MapSearchCategory.airports,
          },
        ),
      );

      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.ready);
      expect(cubit.state.query, 'Madrid');

      await cubit.close();
    });

    testWidgets('clearing invalidates pending searches', (tester) async {
      final request = Completer<MapSearchResults>();

      final cubit = MapSearchCubit(search: (_) => request.future);

      cubit.queryChanged('Lisbon');

      await tester.pump(const Duration(milliseconds: 300));

      expect(cubit.state.phase, MapSearchPhase.loading);

      cubit.clear();

      expect(cubit.state.phase, MapSearchPhase.idle);
      expect(cubit.state.query, '');

      request.complete(MapSearchResults());

      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.idle);

      await cubit.close();
    });

    testWidgets('clear cancels pending debounce', (tester) async {
      var searchCount = 0;

      final cubit = MapSearchCubit(
        search: (_) async {
          searchCount++;
          return MapSearchResults();
        },
      );

      cubit.queryChanged('Lisbon');

      cubit.clear();

      await tester.pump(const Duration(milliseconds: 500));

      expect(searchCount, 0);
      expect(cubit.state.phase, MapSearchPhase.idle);

      await cubit.close();
    });

    testWidgets('reports failure when all categories fail', (tester) async {
      final cubit = MapSearchCubit(
        search: (_) async => MapSearchResults(
          failedCategories: {
            MapSearchCategory.countries,
            MapSearchCategory.cities,
            MapSearchCategory.airports,
          },
        ),
      );

      cubit.queryChanged('Lisbon');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.failure);
      expect(cubit.state.hasErrors, isTrue);

      await cubit.close();
    });

    testWidgets('retry executes search immediately', (tester) async {
      var searchCount = 0;

      final cubit = MapSearchCubit(
        search: (_) async {
          searchCount++;

          if (searchCount == 1) {
            throw StateError('Search unavailable');
          }

          return MapSearchResults();
        },
      );

      cubit.queryChanged('Madrid');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.failure);
      expect(searchCount, 1);

      cubit.retry();

      await tester.pump();

      expect(searchCount, 2);
      expect(cubit.state.phase, MapSearchPhase.ready);

      await cubit.close();
    });

    testWidgets('does not update state after close', (tester) async {
      final request = Completer<MapSearchResults>();

      final cubit = MapSearchCubit(search: (_) => request.future);

      cubit.queryChanged('Madrid');

      await tester.pump(const Duration(milliseconds: 300));

      await cubit.close();

      request.complete(MapSearchResults());

      await tester.pump();

      expect(cubit.isClosed, isTrue);
    });
    testWidgets('shows progressive results while airports remain pending', (
      tester,
    ) async {
      final airportRequest = Completer<MapSearchResults>();

      final cubit = MapSearchCubit(
        search: (_) async => MapSearchResults(),
        progressiveSearch: (query, onProgress) async {
          final countries = MapSearchResults();

          onProgress(countries, {MapSearchCategory.countries});

          onProgress(countries, {
            MapSearchCategory.countries,
            MapSearchCategory.cities,
          });

          return airportRequest.future;
        },
      );

      cubit.queryChanged('port');

      await tester.pump(const Duration(milliseconds: 300));

      expect(cubit.state.phase, MapSearchPhase.loading);

      expect(cubit.state.pendingCategories, {MapSearchCategory.airports});

      airportRequest.complete(MapSearchResults());

      await tester.pump();

      expect(cubit.state.phase, MapSearchPhase.ready);

      expect(cubit.state.pendingCategories, isEmpty);

      await cubit.close();
    });
  });
}
