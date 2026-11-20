/// A single personal flight associated with a geographic route.
///
/// Flight direction is preserved even when multiple flights
/// share one undirected visual connection.
class MapFlightRouteFlight {
  const MapFlightRouteFlight({
    required this.flightId,
    required this.departureAirportId,
    required this.arrivalAirportId,
  });

  final String flightId;

  final int departureAirportId;
  final int arrivalAirportId;
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
