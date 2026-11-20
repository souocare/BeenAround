/// Geographic projection of an airport used in the
/// authenticated user's completed flight history.
///
/// This is derived, read-only data.
///
/// Airports do not imply visits to their countries or cities.
class MapAirportData {
  const MapAirportData({
    required this.airportId,
    required this.code,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.departureCount,
    required this.arrivalCount,
    required this.flightCount,
  });

  final int airportId;

  final String code;
  final String name;
  final String? countryCode;

  final double latitude;
  final double longitude;

  final int departureCount;
  final int arrivalCount;

  /// Number of distinct completed flight segments
  /// involving this airport.
  ///
  /// A flight departing from and arriving at the same
  /// airport counts only once.
  final int flightCount;
}
