import '../domain/country.dart';
import 'explore_state.dart';

enum VisitedCountriesFilter { all, multipleVisits }

enum VisitedCountriesSort { nameAscending, nameDescending, mostVisited }

class VisitedCountriesFilterOptions {
  const VisitedCountriesFilterOptions({
    this.query = '',
    this.filter = VisitedCountriesFilter.all,
    this.sort = VisitedCountriesSort.nameAscending,
  });

  final String query;
  final VisitedCountriesFilter filter;
  final VisitedCountriesSort sort;
}

List<Country> filterVisitedCountries(
  ExploreState state, {
  VisitedCountriesFilterOptions options = const VisitedCountriesFilterOptions(),
}) {
  final query = options.query.trim().toLowerCase();

  final visitCounts = <String, int>{};

  for (final visit in state.visits) {
    visitCounts.update(
      visit.countryCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  final countries = state.countries.where((country) {
    final count = visitCounts[country.code] ?? 0;

    if (count == 0) return false;

    if (options.filter == VisitedCountriesFilter.multipleVisits && count < 2) {
      return false;
    }

    if (query.isEmpty) return true;

    return country.name.toLowerCase().contains(query) ||
        country.code.toLowerCase().contains(query) ||
        country.alpha3Code.toLowerCase().contains(query);
  }).toList();

  switch (options.sort) {
    case VisitedCountriesSort.nameAscending:
      countries.sort((a, b) => a.name.compareTo(b.name));

    case VisitedCountriesSort.nameDescending:
      countries.sort((a, b) => b.name.compareTo(a.name));

    case VisitedCountriesSort.mostVisited:
      countries.sort((a, b) {
        final countComparison = (visitCounts[b.code] ?? 0).compareTo(
          visitCounts[a.code] ?? 0,
        );

        return countComparison != 0
            ? countComparison
            : a.name.compareTo(b.name);
      });
  }

  return List.unmodifiable(countries);
}
