/// Aggregated travel status for a country.
///
/// This is a read model. It never creates or modifies domain records.
///
/// Country visits and country wishlist entries are explicit.
/// City residences contribute to the country's lived status
/// without creating a direct country residence.
class ExploreCountrySummary {
  const ExploreCountrySummary({
    required this.countryCode,
    required this.visitCount,
    required this.directResidenceCount,
    required this.cityResidenceCount,
    required this.isWishlisted,
  });

  final String countryCode;

  /// Number of explicit country visits.
  final int visitCount;

  /// Residences explicitly registered against the country.
  final int directResidenceCount;

  /// Residences registered against cities in this country.
  final int cityResidenceCount;

  /// Whether the country itself is explicitly wishlisted.
  final bool isWishlisted;

  bool get hasBeen => visitCount > 0;

  bool get hasMultipleVisits => visitCount >= 2;

  bool get hasDirectResidence => directResidenceCount > 0;

  bool get hasCityResidence => cityResidenceCount > 0;

  bool get hasLived => directResidenceCount > 0 || cityResidenceCount > 0;

  int get totalResidenceCount => directResidenceCount + cityResidenceCount;

  bool get hasAnyStatus => hasBeen || hasLived || isWishlisted;
}
