import '../domain/airline.dart';
import '../domain/airline_repository.dart';
import '../domain/flight_number.dart';

/// Resolves a potential airline from a flight number.
///
/// Detection is advisory. It never modifies a flight or creates
/// airline catalog entries.
class FlightAirlineDetector {
  const FlightAirlineDetector({required AirlineRepository repository})
    : _repository = repository;

  final AirlineRepository _repository;

  /// Returns an airline only when the catalog gives an
  /// unambiguous exact-code match.
  ///
  /// An incomplete search result must not be treated as proof
  /// that a code belongs to exactly one airline.
  Future<Airline?> detect(String flightNumber) async {
    final candidates = FlightNumber.airlineCodeCandidates(flightNumber);

    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      final page = await _repository.search(query: candidate, limit: 100);

      // We cannot establish uniqueness from a partial result set.
      if (page.hasMore) {
        continue;
      }

      final matches = page.items
          .where((airline) {
            final iata = airline.iataCode?.trim().toUpperCase();
            final icao = airline.icaoCode?.trim().toUpperCase();

            return iata == candidate || icao == candidate;
          })
          .toList(growable: false);

      final uniqueById = {for (final airline in matches) airline.id: airline};

      if (uniqueById.length == 1) {
        return uniqueById.values.single;
      }

      // Multiple exact matches are ambiguous. Do not silently
      // choose the first catalog entry.
      if (uniqueById.length > 1) {
        return null;
      }
    }

    return null;
  }
}
