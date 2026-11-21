import '../../flights/domain/flight.dart';
import '../domain/map_flight_route.dart';

/// Builds unique visual connections from completed personal flights.
///
/// Rules:
/// - Planned flights are excluded.
/// - Duplicate flight IDs are ignored.
/// - Connections are direction-independent.
/// - Original flight direction is preserved.
/// - One airport pair produces exactly one visual route.
/// - Invalid airport IDs are ignored.
/// - Same-airport flights do not produce a drawable connection.
///
/// No catalog requests or geographic calculations occur here.
///
/// The result is deterministic and read-only.
List<MapFlightRoute> buildMapFlightRouteProjection({
  required Iterable<Flight> flights,
}) {
  final seenFlightIds = <String>{};

  final groupedFlights = <String, List<MapFlightRouteFlight>>{};

  final routeAirportIds = <String, (int, int)>{};

  for (final flight in flights) {
    // -----------------------------------------------------------------------
    // Only completed personal flights contribute to traveled routes.
    // -----------------------------------------------------------------------

    if (!flight.isFlown) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Validate geographic endpoint identifiers.
    // -----------------------------------------------------------------------

    final departureId = flight.departureAirportId;
    final arrivalId = flight.arrivalAirportId;

    if (departureId <= 0 || arrivalId <= 0) {
      continue;
    }

    // A route between the same airport cannot be represented
    // as a conventional airport-to-airport connection.
    //
    // The flight itself remains valid and is not modified.
    if (departureId == arrivalId) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Ignore duplicate flight records in the projection.
    //
    // The repository should normally provide unique records,
    // but the projection remains defensive.
    // -----------------------------------------------------------------------

    if (!seenFlightIds.add(flight.id)) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Normalize connection identity.
    //
    // A -> B and B -> A are the same visual connection.
    // -----------------------------------------------------------------------

    final firstAirportId = departureId < arrivalId ? departureId : arrivalId;

    final secondAirportId = departureId < arrivalId ? arrivalId : departureId;

    final routeId = '$firstAirportId:$secondAirportId';

    routeAirportIds[routeId] = (firstAirportId, secondAirportId);

    groupedFlights
        .putIfAbsent(routeId, () => <MapFlightRouteFlight>[])
        .add(
          MapFlightRouteFlight(
            flightId: flight.id,
            departureAirportId: departureId,
            arrivalAirportId: arrivalId,
            departureOn: flight.departureOn,
            flightNumber: flight.flightNumber,
            airlineName: flight.airlineName,
          ),
        );
  }

  // -------------------------------------------------------------------------
  // Build deterministic, immutable output.
  //
  // Sorting does not alter flight chronology in the domain.
  // It only stabilizes the projection across equivalent inputs.
  // -------------------------------------------------------------------------

  final routeIds = groupedFlights.keys.toList()
    ..sort((a, b) {
      final aIds = routeAirportIds[a]!;
      final bIds = routeAirportIds[b]!;

      final firstComparison = aIds.$1.compareTo(bIds.$1);

      if (firstComparison != 0) {
        return firstComparison;
      }

      return aIds.$2.compareTo(bIds.$2);
    });

  return List<MapFlightRoute>.unmodifiable([
    for (final routeId in routeIds)
      MapFlightRoute(
        firstAirportId: routeAirportIds[routeId]!.$1,
        secondAirportId: routeAirportIds[routeId]!.$2,
        flights: List<MapFlightRouteFlight>.unmodifiable(
          [...groupedFlights[routeId]!]..sort((a, b) {
            final dateA = a.departureOn;
            final dateB = b.departureOn;

            // Real flight projections always contain departureOn.
            // Keep a deterministic fallback for legacy fixtures.
            if (dateA == null && dateB != null) return 1;
            if (dateA != null && dateB == null) return -1;

            if (dateA != null && dateB != null) {
              final dateComparison = dateB.compareTo(dateA);

              if (dateComparison != 0) {
                return dateComparison;
              }
            }

            return a.flightId.compareTo(b.flightId);
          }),
        ),
      ),
  ]);
}
