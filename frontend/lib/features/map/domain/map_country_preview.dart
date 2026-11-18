/// Read-only summary of a country selected on the travel map.
///
/// This model does not own or modify travel records.
/// All values are derived from existing domain data.
class MapCountryPreview {
  const MapCountryPreview({
    required this.countryCode,
    required this.countryName,
    required this.visitCount,
    required this.residenceCount,
    required this.isCountryWishlisted,
    required this.hasWishlistedCities,
  });

  final String countryCode;
  final String countryName;

  /// Number of explicit country visits.
  final int visitCount;

  /// Number of residence periods associated with this country,
  /// including residences in cities.
  final int residenceCount;

  /// Whether the country itself was added to the global wishlist.
  final bool isCountryWishlisted;

  /// Whether at least one city in this country was wishlisted.
  final bool hasWishlistedCities;

  bool get hasVisited => visitCount > 0;

  bool get hasLived => residenceCount > 0;

  bool get appearsInWishlist => isCountryWishlisted || hasWishlistedCities;

  bool get hasAnyStatus => hasVisited || hasLived || appearsInWishlist;
}
