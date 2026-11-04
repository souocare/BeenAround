import 'package:beenaround/features/explore/application/explore_countries_filter.dart';
import 'package:beenaround/features/explore/application/explore_country_aggregation.dart';
import 'package:beenaround/features/explore/application/explore_country_summary.dart';
import 'package:beenaround/features/explore/application/explore_destination_filter.dart';
import 'package:beenaround/features/explore/domain/country.dart';

import 'package:flutter_test/flutter_test.dart';

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

const japan = Country(
  code: 'JP',
  name: 'Japan',
  alpha3Code: 'JPN',
  continent: 'Asia',
);

const france = Country(
  code: 'FR',
  name: 'France',
  alpha3Code: 'FRA',
  continent: 'Europe',
);

const germany = Country(
  code: 'DE',
  name: 'Germany',
  alpha3Code: 'DEU',
  continent: 'Europe',
);

ExploreCountryEntry entry(
  Country country, {
  int visits = 0,
  int directResidences = 0,
  int cityResidences = 0,
  bool wish = false,
}) {
  return ExploreCountryEntry(
    country: country,
    summary: ExploreCountrySummary(
      countryCode: country.code,
      visitCount: visits,
      directResidenceCount: directResidences,
      cityResidenceCount: cityResidences,
      isWishlisted: wish,
    ),
  );
}

void main() {
  final entries = [
    entry(portugal, visits: 3, directResidences: 1),
    entry(spain, visits: 1),
    entry(japan, wish: true),
    entry(france, cityResidences: 2, wish: true),
    entry(germany),
  ];

  List<String> codes(List<ExploreCountryEntry> result) {
    return result.map((entry) => entry.country.code).toList();
  }

  group('Explore countries filtering', () {
    test('All includes only countries with travel status', () {
      final result = filterExploreCountries(entries);

      expect(codes(result), ['FR', 'JP', 'PT', 'ES']);
      expect(codes(result), isNot(contains('DE')));
    });

    test('Been includes only explicitly visited countries', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          filter: ExploreDestinationFilter.been,
        ),
      );

      expect(codes(result), ['PT', 'ES']);
    });

    test('Lived includes direct and city residences', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          filter: ExploreDestinationFilter.lived,
        ),
      );

      expect(codes(result), ['FR', 'PT']);
    });

    test('Wish includes only explicitly wishlisted countries', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          filter: ExploreDestinationFilter.wish,
        ),
      );

      expect(codes(result), ['FR', 'JP']);
    });

    test('Multiple visits requires at least two explicit visits', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          filter: ExploreDestinationFilter.multipleVisits,
        ),
      );

      expect(codes(result), ['PT']);
    });

    test('searches by country name', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(query: 'port'),
      );

      expect(codes(result), ['PT']);
    });

    test('searches by alpha-2 code', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(query: 'jp'),
      );

      expect(codes(result), ['JP']);
    });

    test('searches by alpha-3 code', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(query: 'FRA'),
      );

      expect(codes(result), ['FR']);
    });

    test('trims whitespace and ignores case', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(query: '  PORTUGAL  '),
      );

      expect(codes(result), ['PT']);
    });

    test('combines search with status filtering', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          query: 'france',
          filter: ExploreDestinationFilter.wish,
        ),
      );

      expect(codes(result), ['FR']);
    });

    test('does not match a country outside the selected status', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          query: 'france',
          filter: ExploreDestinationFilter.been,
        ),
      );

      expect(result, isEmpty);
    });

    test('sorts countries by name descending', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          sort: ExploreDestinationSort.nameDescending,
        ),
      );

      expect(codes(result), ['ES', 'PT', 'JP', 'FR']);
    });

    test('sorts by number of explicit visits', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          sort: ExploreDestinationSort.mostVisited,
        ),
      );

      expect(codes(result), ['PT', 'ES', 'FR', 'JP']);
    });

    test('returns empty when nothing matches', () {
      final result = filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(query: 'Brazil'),
      );

      expect(result, isEmpty);
    });

    test('does not modify the source collection', () {
      final originalOrder = codes(entries);

      filterExploreCountries(
        entries,
        options: const ExploreCountriesFilterOptions(
          sort: ExploreDestinationSort.mostVisited,
        ),
      );

      expect(codes(entries), originalOrder);
    });

    test('returns an immutable collection', () {
      final result = filterExploreCountries(entries);

      expect(() => result.clear(), throwsUnsupportedError);
    });
  });
}
