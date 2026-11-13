import '../domain/airline.dart';
import '../domain/airline_repository.dart';
import '../domain/airport.dart';
import '../domain/airport_repository.dart';
import '../domain/flight.dart';

/// Resolved catalog information for a collection of flights.
///
/// A missing catalog entry is represented by null.
/// Flight records remain valid independently of display metadata.
class ResolvedFlightCatalog {
  ResolvedFlightCatalog({
    required Map<int, Airport> airports,
    required Map<int, Airline> airlines,
  }) : airports = Map.unmodifiable(airports),
       airlines = Map.unmodifiable(airlines);

  final Map<int, Airport> airports;
  final Map<int, Airline> airlines;

  Airport? airportFor(int airportId) => airports[airportId];

  Airline? airlineFor(int airlineId) => airlines[airlineId];

  String? airlineNameFor(Flight flight) {
    if (flight.airlineId != null) {
      return airlines[flight.airlineId]?.name;
    }

    return flight.airlineName;
  }
}

/// Resolves aviation catalog references using an in-memory cache.
///
/// Successful responses are cached for the lifetime of this resolver.
///
/// Concurrent requests for the same ID share one HTTP operation.
/// Failed requests are not cached, allowing future retries.
///
/// No visits, Trips or other travel records are created or modified.
class FlightCatalogResolver {
  FlightCatalogResolver({
    required AirportRepository airportRepository,
    required AirlineRepository airlineRepository,
  }) : _airportRepository = airportRepository,
       _airlineRepository = airlineRepository;

  final AirportRepository _airportRepository;
  final AirlineRepository _airlineRepository;

  final Map<int, Airport> _airports = {};
  final Map<int, Airline> _airlines = {};

  final Map<int, Future<Airport>> _pendingAirports = {};
  final Map<int, Future<Airline>> _pendingAirlines = {};

  /// Resolve the unique catalog references used by these flights.
  ///
  /// The returned snapshot includes only entries referenced by the
  /// supplied flights, rather than exposing the entire internal cache.
  Future<ResolvedFlightCatalog> resolve(Iterable<Flight> flights) async {
    final airportIds = <int>{};
    final airlineIds = <int>{};

    for (final flight in flights) {
      airportIds.add(flight.departureAirportId);
      airportIds.add(flight.arrivalAirportId);

      if (flight.airlineId != null) {
        airlineIds.add(flight.airlineId!);
      }
    }

    await Future.wait<void>([
      for (final id in airportIds)
        _resolveAirport(
          id,
        ).then((_) {}, onError: (Object error, StackTrace stackTrace) {}),

      for (final id in airlineIds)
        _resolveAirline(
          id,
        ).then((_) {}, onError: (Object error, StackTrace stackTrace) {}),
    ]);

    return ResolvedFlightCatalog(
      airports: {
        for (final id in airportIds)
          if (_airports[id] != null) id: _airports[id]!,
      },
      airlines: {
        for (final id in airlineIds)
          if (_airlines[id] != null) id: _airlines[id]!,
      },
    );
  }

  Future<Airport> _resolveAirport(int airportId) {
    final cached = _airports[airportId];

    if (cached != null) {
      return Future.value(cached);
    }

    return _pendingAirports.putIfAbsent(
      airportId,
      () => _fetchAirport(airportId),
    );
  }

  Future<Airline> _resolveAirline(int airlineId) {
    final cached = _airlines[airlineId];

    if (cached != null) {
      return Future.value(cached);
    }

    return _pendingAirlines.putIfAbsent(
      airlineId,
      () => _fetchAirline(airlineId),
    );
  }

  Future<Airport> _fetchAirport(int airportId) async {
    try {
      final airport = await _airportRepository.getAirport(airportId: airportId);

      _airports[airportId] = airport;

      return airport;
    } finally {
      _pendingAirports.remove(airportId);
    }
  }

  Future<Airline> _fetchAirline(int airlineId) async {
    try {
      final airline = await _airlineRepository.getAirline(airlineId: airlineId);

      _airlines[airlineId] = airline;

      return airline;
    } finally {
      _pendingAirlines.remove(airlineId);
    }
  }

  /// Clear cached metadata.
  ///
  /// This is useful when a different server or authenticated
  /// application session is configured.
  void clear() {
    _airports.clear();
    _airlines.clear();
  }
}
