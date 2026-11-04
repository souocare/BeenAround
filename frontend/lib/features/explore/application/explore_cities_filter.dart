import 'explore_city_aggregation.dart';
import 'explore_destination_filter.dart';

class ExploreCitiesFilterOptions {
  const ExploreCitiesFilterOptions({
    this.query = '',
    this.filter = ExploreDestinationFilter.all,
    this.sort = ExploreDestinationSort.nameAscending,
  });

  final String query;
  final ExploreDestinationFilter filter;
  final ExploreDestinationSort sort;
}

/// Filters and sorts the user's aggregated city travel history.
///
/// Only cities with an explicit Been, Lived or Wish status are included.
/// This function does not access repositories or modify source records.
List<ExploreCityEntry> filterExploreCities(
  List<ExploreCityEntry> entries, {
  ExploreCitiesFilterOptions options = const ExploreCitiesFilterOptions(),
}) {
  final query = options.query.trim().toLowerCase();

  final result = entries.where((entry) {
    final city = entry.city;
    final summary = entry.summary;

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

    return city.name.toLowerCase().contains(query) ||
        (city.asciiName?.toLowerCase().contains(query) ?? false) ||
        city.countryName.toLowerCase().contains(query) ||
        city.countryCode.toLowerCase().contains(query);
  }).toList();

  result.sort((a, b) {
    final nameComparison = a.city.name.toLowerCase().compareTo(
      b.city.name.toLowerCase(),
    );

    final countryComparison = a.city.countryCode.compareTo(b.city.countryCode);

    final idComparison = a.city.id.compareTo(b.city.id);

    int compareByName() {
      if (nameComparison != 0) return nameComparison;
      if (countryComparison != 0) return countryComparison;
      return idComparison;
    }

    switch (options.sort) {
      case ExploreDestinationSort.nameAscending:
        return compareByName();

      case ExploreDestinationSort.nameDescending:
        if (nameComparison != 0) return -nameComparison;
        if (countryComparison != 0) return countryComparison;
        return idComparison;

      case ExploreDestinationSort.mostVisited:
        final countComparison = b.summary.visitCount.compareTo(
          a.summary.visitCount,
        );

        return countComparison != 0 ? countComparison : compareByName();
    }
  });

  return List.unmodifiable(result);
}
