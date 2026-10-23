import 'package:beenaround/features/explore/application/explore_state.dart';
import 'package:beenaround/features/explore/application/visited_countries_filter.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
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

const france = Country(
  code: 'FR',
  name: 'France',
  alpha3Code: 'FRA',
  continent: 'Europe',
);

CountryVisit visit(String id, String countryCode) {
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
  final state = ExploreState(
    phase: ExplorePhase.ready,
    countries: const [spain, france, portugal],
    visits: [visit('1', 'PT'), visit('2', 'PT'), visit('3', 'ES')],
  );

  test('only includes visited countries', () {
    final result = filterVisitedCountries(state);

    expect(result.map((country) => country.code), ['PT', 'ES']);
  });

  test('searches by country name', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(query: 'port'),
    );

    expect(result.map((country) => country.code), ['PT']);
  });

  test('searches by alpha-2 country code', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(query: 'es'),
    );

    expect(result.map((country) => country.code), ['ES']);
  });

  test('searches by alpha-3 country code', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(query: 'PRT'),
    );

    expect(result.map((country) => country.code), ['PT']);
  });

  test('filters countries with multiple visits', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(
        filter: VisitedCountriesFilter.multipleVisits,
      ),
    );

    expect(result.map((country) => country.code), ['PT']);
  });

  test('sorts by most visited', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(
        sort: VisitedCountriesSort.mostVisited,
      ),
    );

    expect(result.map((country) => country.code), ['PT', 'ES']);
  });

  test('sorts by name descending', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(
        sort: VisitedCountriesSort.nameDescending,
      ),
    );

    expect(result.map((country) => country.code), ['ES', 'PT']);
  });

  test('returns empty when search has no matches', () {
    final result = filterVisitedCountries(
      state,
      options: const VisitedCountriesFilterOptions(query: 'Japan'),
    );

    expect(result, isEmpty);
  });
}
