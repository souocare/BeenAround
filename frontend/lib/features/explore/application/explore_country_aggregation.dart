import '../domain/country.dart';

import '../../residences/application/residences_state.dart';
import '../../wishlist/application/wishlist_state.dart';

import 'explore_country_summary.dart';
import 'explore_state.dart';

/// Country catalogue entry with its aggregated travel status.
class ExploreCountryEntry {
  const ExploreCountryEntry({required this.country, required this.summary});

  final Country country;
  final ExploreCountrySummary summary;
}

/// Builds country-level read models from independent travel records.
///
/// Important domain rules:
/// - Only explicit country visits count towards Been.
/// - City residences contribute to Lived at country level.
/// - City wishlist entries do not imply a country wishlist entry.
/// - Aggregation never creates or changes persisted records.
List<ExploreCountryEntry> aggregateExploreCountries({
  required ExploreState explore,
  required ResidencesState residences,
  required WishlistState wishlist,
}) {
  final visitCounts = <String, int>{};

  final directResidenceCounts = <String, int>{};
  final cityResidenceCounts = <String, int>{};

  final wishlistedCountries = <String>{};

  // ------------------------------------------------------------
  // Explicit country visits
  // ------------------------------------------------------------

  for (final visit in explore.visits) {
    visitCounts.update(
      visit.countryCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  // ------------------------------------------------------------
  // Residence history
  // ------------------------------------------------------------

  for (final residence in residences.residences) {
    final counts = residence.cityId == null
        ? directResidenceCounts
        : cityResidenceCounts;

    counts.update(
      residence.countryCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  // ------------------------------------------------------------
  // Explicit country wishlist entries
  // ------------------------------------------------------------

  for (final entry in wishlist.entries) {
    final countryCode = entry.countryCode;

    if (countryCode != null) {
      wishlistedCountries.add(countryCode);
    }
  }

  // ------------------------------------------------------------
  // Aggregate catalogue countries
  // ------------------------------------------------------------

  final result = [
    for (final country in explore.countries)
      ExploreCountryEntry(
        country: country,
        summary: ExploreCountrySummary(
          countryCode: country.code,
          visitCount: visitCounts[country.code] ?? 0,
          directResidenceCount: directResidenceCounts[country.code] ?? 0,
          cityResidenceCount: cityResidenceCounts[country.code] ?? 0,
          isWishlisted: wishlistedCountries.contains(country.code),
        ),
      ),
  ];

  return List.unmodifiable(result);
}
