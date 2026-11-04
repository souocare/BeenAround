import 'package:beenaround/features/explore/application/explore_cities_filter.dart';
import 'package:beenaround/features/explore/application/explore_city_aggregation.dart';
import 'package:beenaround/features/explore/application/explore_city_summary.dart';
import 'package:beenaround/features/explore/application/explore_destination_filter.dart';
import 'package:beenaround/features/geography/domain/city.dart';

import 'package:flutter_test/flutter_test.dart';

City makeCity({
  required int id,
  required String name,
  required String countryCode,
  required String countryName,
  String? asciiName,
}) {
  return City(
    id: id,
    name: name,
    asciiName: asciiName ?? name,
    countryCode: countryCode,
    countryName: countryName,
    latitude: 0,
    longitude: 0,
    population: 1000,
    featureCode: 'PPL',
  );
}

ExploreCityEntry makeEntry({
  required City city,
  int visits = 0,
  int residences = 0,
  bool wish = false,
}) {
  return ExploreCityEntry(
    city: city,
    summary: ExploreCitySummary(
      cityId: city.id,
      visitCount: visits,
      residenceCount: residences,
      isWishlisted: wish,
    ),
  );
}

void main() {
  final lisbon = makeCity(
    id: 1,
    name: 'Lisboa',
    asciiName: 'Lisboa',
    countryCode: 'PT',
    countryName: 'Portugal',
  );

  final porto = makeCity(
    id: 2,
    name: 'Porto',
    countryCode: 'PT',
    countryName: 'Portugal',
  );

  final tokyo = makeCity(
    id: 3,
    name: 'Tokyo',
    countryCode: 'JP',
    countryName: 'Japan',
  );

  final paris = makeCity(
    id: 4,
    name: 'Paris',
    countryCode: 'FR',
    countryName: 'France',
  );

  final berlin = makeCity(
    id: 5,
    name: 'Berlin',
    countryCode: 'DE',
    countryName: 'Germany',
  );

  final saoPaulo = makeCity(
    id: 6,
    name: 'São Paulo',
    asciiName: 'Sao Paulo',
    countryCode: 'BR',
    countryName: 'Brazil',
  );

  final entries = [
    makeEntry(city: lisbon, visits: 3, residences: 1),
    makeEntry(city: porto, visits: 1),
    makeEntry(city: tokyo, wish: true),
    makeEntry(city: paris, residences: 2, wish: true),
    makeEntry(city: berlin),
    makeEntry(city: saoPaulo, visits: 2),
  ];

  List<int> ids(List<ExploreCityEntry> result) =>
      result.map((entry) => entry.city.id).toList();

  group('Explore cities filtering', () {
    test('All includes only cities with travel status', () {
      final result = filterExploreCities(entries);

      expect(ids(result), [1, 4, 2, 6, 3]);
      expect(ids(result), isNot(contains(5)));
    });

    test('Been includes only explicitly visited cities', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          filter: ExploreDestinationFilter.been,
        ),
      );

      expect(ids(result), [1, 2, 6]);
    });

    test('Lived includes cities with residences', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          filter: ExploreDestinationFilter.lived,
        ),
      );

      expect(ids(result), [1, 4]);
    });

    test('Wish includes only explicitly wishlisted cities', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          filter: ExploreDestinationFilter.wish,
        ),
      );

      expect(ids(result), [4, 3]);
    });

    test('Multiple visits requires at least two city visits', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          filter: ExploreDestinationFilter.multipleVisits,
        ),
      );

      expect(ids(result), [1, 6]);
    });

    test('searches by city name', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: 'porto'),
      );

      expect(ids(result), [2]);
    });

    test('searches by ASCII city name', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: 'sao paulo'),
      );

      expect(ids(result), [6]);
    });

    test('searches by country name', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: 'portugal'),
      );

      expect(ids(result), [1, 2]);
    });

    test('searches by country code', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: 'jp'),
      );

      expect(ids(result), [3]);
    });

    test('trims whitespace and ignores case', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: '  TOKYO  '),
      );

      expect(ids(result), [3]);
    });

    test('combines search with a status filter', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          query: 'france',
          filter: ExploreDestinationFilter.wish,
        ),
      );

      expect(ids(result), [4]);
    });

    test('does not infer Been from Lived or Wish', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          query: 'paris',
          filter: ExploreDestinationFilter.been,
        ),
      );

      expect(result, isEmpty);
    });

    test('sorts by name descending', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          sort: ExploreDestinationSort.nameDescending,
        ),
      );

      expect(ids(result), [3, 6, 2, 4, 1]);
    });

    test('sorts by explicit visit count', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          sort: ExploreDestinationSort.mostVisited,
        ),
      );

      expect(ids(result), [1, 6, 2, 4, 3]);
    });

    test('orders equal names by country and ID', () {
      final first = makeCity(
        id: 10,
        name: 'Springfield',
        countryCode: 'US',
        countryName: 'United States',
      );

      final second = makeCity(
        id: 8,
        name: 'Springfield',
        countryCode: 'CA',
        countryName: 'Canada',
      );

      final third = makeCity(
        id: 7,
        name: 'Springfield',
        countryCode: 'CA',
        countryName: 'Canada',
      );

      final result = filterExploreCities([
        makeEntry(city: first, visits: 1),
        makeEntry(city: second, visits: 1),
        makeEntry(city: third, visits: 1),
      ]);

      expect(ids(result), [7, 8, 10]);
    });

    test('does not mutate source entries', () {
      final original = ids(entries);

      filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(
          sort: ExploreDestinationSort.mostVisited,
        ),
      );

      expect(ids(entries), original);
    });

    test('returns an immutable result', () {
      final result = filterExploreCities(entries);

      expect(() => result.clear(), throwsUnsupportedError);
    });

    test('returns empty when no cities match', () {
      final result = filterExploreCities(
        entries,
        options: const ExploreCitiesFilterOptions(query: 'Reykjavik'),
      );

      expect(result, isEmpty);
    });
  });
  test('handles cities without an ASCII name', () {
    final city = City(
      id: 99,
      name: 'Test City',
      asciiName: null,
      countryCode: 'PT',
      countryName: 'Portugal',
      latitude: 0,
      longitude: 0,
      population: 1000,
      featureCode: 'PPL',
    );

    final result = filterExploreCities([
      makeEntry(city: city, visits: 1),
    ], options: const ExploreCitiesFilterOptions(query: 'test'));

    expect(result.map((entry) => entry.city.id), [99]);
  });
}
