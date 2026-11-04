import '../../geography/domain/city.dart';
import '../../residences/application/residences_state.dart';
import '../../wishlist/application/wishlist_state.dart';

import 'explore_city_summary.dart';
import 'visited_cities_state.dart';

/// A catalog city and its aggregated travel status.
class ExploreCityEntry {
  const ExploreCityEntry({required this.city, required this.summary});

  final City city;
  final ExploreCitySummary summary;
}

/// Collects distinct city IDs referenced by travel records.
///
/// Country-only residences and wishlist entries do not imply
/// any city-level status.
List<int> collectExploreCityIds({
  required VisitedCitiesState visitedCities,
  required ResidencesState residences,
  required WishlistState wishlist,
}) {
  final ids = <int>{};

  for (final visit in visitedCities.visits) {
    ids.add(visit.cityId);
  }

  for (final residence in residences.residences) {
    final cityId = residence.cityId;

    if (cityId != null) {
      ids.add(cityId);
    }
  }

  for (final entry in wishlist.entries) {
    final cityId = entry.cityId;

    if (cityId != null) {
      ids.add(cityId);
    }
  }

  return List.unmodifiable(ids);
}

/// Aggregates Been, Lived and Wish for catalog cities.
///
/// The aggregation is pure:
/// - No network or database access.
/// - No creation of visits or residences.
/// - No implicit parent-country associations.
/// - No changes to the source records.
///
/// Every referenced city must have resolved catalog metadata.
/// Missing metadata is reported instead of silently hiding
/// a destination from Explore.
List<ExploreCityEntry> aggregateExploreCities({
  required List<City> cities,
  required VisitedCitiesState visitedCities,
  required ResidencesState residences,
  required WishlistState wishlist,
}) {
  final visitCounts = <int, int>{};
  final residenceCounts = <int, int>{};
  final wishlistedCityIds = <int>{};

  for (final visit in visitedCities.visits) {
    visitCounts.update(visit.cityId, (count) => count + 1, ifAbsent: () => 1);
  }

  for (final residence in residences.residences) {
    final cityId = residence.cityId;

    if (cityId == null) continue;

    residenceCounts.update(cityId, (count) => count + 1, ifAbsent: () => 1);
  }

  for (final entry in wishlist.entries) {
    final cityId = entry.cityId;

    if (cityId != null) {
      wishlistedCityIds.add(cityId);
    }
  }

  final referencedIds = collectExploreCityIds(
    visitedCities: visitedCities,
    residences: residences,
    wishlist: wishlist,
  ).toSet();

  final resolvedCities = <int, City>{for (final city in cities) city.id: city};

  final missingIds = referencedIds.difference(resolvedCities.keys.toSet());

  if (missingIds.isNotEmpty) {
    throw StateError(
      'Unable to resolve catalog metadata for '
      '${missingIds.length} referenced cities.',
    );
  }

  final result = [
    for (final city in resolvedCities.values)
      if (referencedIds.contains(city.id))
        ExploreCityEntry(
          city: city,
          summary: ExploreCitySummary(
            cityId: city.id,
            visitCount: visitCounts[city.id] ?? 0,
            residenceCount: residenceCounts[city.id] ?? 0,
            isWishlisted: wishlistedCityIds.contains(city.id),
          ),
        ),
  ];

  result.sort((a, b) {
    final nameComparison = a.city.name.toLowerCase().compareTo(
      b.city.name.toLowerCase(),
    );

    if (nameComparison != 0) return nameComparison;

    final countryComparison = a.city.countryCode.compareTo(b.city.countryCode);

    if (countryComparison != 0) return countryComparison;

    return a.city.id.compareTo(b.city.id);
  });

  return List.unmodifiable(result);
}
