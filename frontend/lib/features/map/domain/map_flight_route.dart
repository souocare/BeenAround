/// A single personal flight associated with a geographic route.
///
/// Flight direction is preserved even when multiple flights
/// share one undirected visual connection.
///
/// Contains only the information required for read-only
/// contextual route presentation.
///
/// Dates remain local calendar values from the flight domain.
/// No timezone conversion occurs here.
class MapFlightRouteFlight {
  const MapFlightRouteFlight({
    required this.flightId,
    required this.departureAirportId,
    required this.arrivalAirportId,
    this.departureOn,
    this.flightNumber,
    this.airlineName,
  });

  final String flightId;

  final int departureAirportId;
  final int arrivalAirportId;

  /// Departure airport's local calendar date (YYYY-MM-DD).
  ///
  /// Optional for compatibility with existing route fixtures.
  /// Real completed-flight projections populate this field.
  final String? departureOn;

  /// Recorded flight number, when available.
  final String? flightNumber;

  /// Recorded textual airline name, when available.
  ///
  /// Flights referencing an airline catalog ID may not
  /// contain a textual name directly.
  final String? airlineName;
}

/// One unique visual connection between two airports.
///
/// Airport IDs are stored in ascending order so that
/// A -> B and B -> A have the same geographic identity.
///
/// Individual flights retain their original direction.
///
/// This is derived, read-only Map data.
/// It does not represent a persisted route entity.
class MapFlightRoute {
  const MapFlightRoute({
    required this.firstAirportId,
    required this.secondAirportId,
    required this.flights,
  });

  final int firstAirportId;
  final int secondAirportId;

  /// All distinct completed flight segments associated
  /// with this visual connection.
  final List<MapFlightRouteFlight> flights;

  /// Stable, direction-independent route identity.
  String get id => '$firstAirportId:$secondAirportId';

  /// Number of individual completed flights.
  ///
  /// This is informational only.
  ///
  /// It must not change line width, opacity or visual weight.
  int get flightCount => flights.length;
}
