import '../../flights/domain/airport.dart';
import '../../flights/domain/flight.dart';

import '../domain/map_airport_data.dart';

/// Builds a read-only geographic projection of airports
/// used in completed personal flights.
///
/// Does not create country visits, city visits, wishlist
/// entries or Trip associations.
Map<int, MapAirportData> buildMapAirportProjection({
  required Iterable<Flight> flights,
  required Map<int, Airport> airports,
}) {
  final counts = <int, _AirportCounts>{};
  final seenFlightIds = <String>{};

  for (final flight in flights) {
    // Planned flights do not represent completed travel.
    if (!flight.isFlown) {
      continue;
    }

    // Defensive deduplication across paginated results.
    if (!seenFlightIds.add(flight.id)) {
      continue;
    }

    final departureId = flight.departureAirportId;
    final arrivalId = flight.arrivalAirportId;

    counts.putIfAbsent(departureId, _AirportCounts.new).departures++;

    counts.putIfAbsent(arrivalId, _AirportCounts.new).arrivals++;

    // A circular flight still counts as one distinct
    // flight for that airport.
    for (final airportId in {departureId, arrivalId}) {
      counts.putIfAbsent(airportId, _AirportCounts.new).flights++;
    }
  }

  final result = <int, MapAirportData>{};

  for (final entry in counts.entries) {
    final airportId = entry.key;
    final airport = airports[airportId];

    // An unresolved airport cannot be placed on the map.
    if (airport == null) {
      continue;
    }

    final latitude = airport.latitude;
    final longitude = airport.longitude;

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      continue;
    }

    final count = entry.value;

    result[airportId] = MapAirportData(
      airportId: airportId,
      code: airport.displayCode,
      name: airport.name,
      countryCode: airport.countryCode,
      latitude: latitude,
      longitude: longitude,
      departureCount: count.departures,
      arrivalCount: count.arrivals,
      flightCount: count.flights,
    );
  }

  return Map<int, MapAirportData>.unmodifiable(result);
}

class _AirportCounts {
  int departures = 0;
  int arrivals = 0;
  int flights = 0;
}
