/// Aggregated travel status for a city.
///
/// This read model combines independent travel records.
/// It never creates or modifies persisted records.
class ExploreCitySummary {
  const ExploreCitySummary({
    required this.cityId,
    required this.visitCount,
    required this.residenceCount,
    required this.isWishlisted,
  });

  final int cityId;
  final int visitCount;
  final int residenceCount;
  final bool isWishlisted;

  bool get hasBeen => visitCount > 0;

  bool get hasMultipleVisits => visitCount >= 2;

  bool get hasLived => residenceCount > 0;

  bool get hasAnyStatus => hasBeen || hasLived || isWishlisted;
}
