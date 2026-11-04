import 'explore_country_aggregation.dart';
import 'explore_destination_filter.dart';

class ExploreCountriesFilterOptions {
  const ExploreCountriesFilterOptions({
    this.query = '',
    this.filter = ExploreDestinationFilter.all,
    this.sort = ExploreDestinationSort.nameAscending,
  });

  final String query;
  final ExploreDestinationFilter filter;
  final ExploreDestinationSort sort;
}

/// Filters and sorts aggregated country travel history.
///
/// Only countries with at least one explicit or derived travel
/// status belong to Explore's personal history.
///
/// This function is pure and never modifies its input.
List<ExploreCountryEntry> filterExploreCountries(
  List<ExploreCountryEntry> entries, {
  ExploreCountriesFilterOptions options = const ExploreCountriesFilterOptions(),
}) {
  final query = options.query.trim().toLowerCase();

  final result = entries.where((entry) {
    final country = entry.country;
    final summary = entry.summary;

    // Countries without travel status are not part of personal history.
    if (!summary.hasAnyStatus) {
      return false;
    }

    final matchesFilter = switch (options.filter) {
      ExploreDestinationFilter.all => true,
      ExploreDestinationFilter.been => summary.hasBeen,
      ExploreDestinationFilter.lived => summary.hasLived,
      ExploreDestinationFilter.wish => summary.isWishlisted,
      ExploreDestinationFilter.multipleVisits => summary.hasMultipleVisits,
    };

    if (!matchesFilter) {
      return false;
    }

    if (query.isEmpty) {
      return true;
    }

    return country.name.toLowerCase().contains(query) ||
        country.code.toLowerCase().contains(query) ||
        country.alpha3Code.toLowerCase().contains(query);
  }).toList();

  result.sort((a, b) {
    final nameComparison = a.country.name.toLowerCase().compareTo(
      b.country.name.toLowerCase(),
    );

    final codeComparison = a.country.code.compareTo(b.country.code);

    switch (options.sort) {
      case ExploreDestinationSort.nameAscending:
        return nameComparison != 0 ? nameComparison : codeComparison;

      case ExploreDestinationSort.nameDescending:
        return nameComparison != 0 ? -nameComparison : codeComparison;

      case ExploreDestinationSort.mostVisited:
        final countComparison = b.summary.visitCount.compareTo(
          a.summary.visitCount,
        );

        if (countComparison != 0) {
          return countComparison;
        }

        return nameComparison != 0 ? nameComparison : codeComparison;
    }
  });

  return List.unmodifiable(result);
}
