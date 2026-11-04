/// Maximum number of city IDs accepted by a single resolution request.
const maxCityResolutionIds = 200;

/// Validates and deduplicates a city ID resolution request.
///
/// Preserves the first occurrence of each ID.
///
/// The request size limit applies before deduplication, matching
/// the backend API contract.
List<int> normalizeCityResolutionIds(List<int> cityIds) {
  if (cityIds.length > maxCityResolutionIds) {
    throw ArgumentError.value(
      cityIds.length,
      'cityIds',
      'Cannot resolve more than $maxCityResolutionIds cities.',
    );
  }

  for (final cityId in cityIds) {
    if (cityId <= 0) {
      throw ArgumentError.value(
        cityId,
        'cityIds',
        'City IDs must be positive integers.',
      );
    }
  }

  return List.unmodifiable(cityIds.toSet());
}
