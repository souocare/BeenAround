import '../domain/airline.dart';
import '../domain/airport.dart';
import '../domain/flight.dart';

enum FlightsPhase { initial, loading, ready, failure }

/// Immutable presentation state for the user's flight history.
class FlightsState {
  FlightsState({
    this.phase = FlightsPhase.initial,
    List<Flight> flights = const [],
    Map<int, Airport> airports = const {},
    Map<int, Airline> airlines = const {},
    this.total = 0,
    this.isLoadingMore = false,
    this.errorMessage,
    this.loadMoreError,
  }) : flights = List.unmodifiable(flights),
       airports = Map.unmodifiable(airports),
       airlines = Map.unmodifiable(airlines);

  final FlightsPhase phase;

  final List<Flight> flights;

  /// Catalog entries required to display loaded flights.
  final Map<int, Airport> airports;
  final Map<int, Airline> airlines;

  /// Total number of flights returned by the backend.
  final int total;

  final bool isLoadingMore;

  /// Error encountered during initial loading or refreshing.
  final String? errorMessage;

  /// Error encountered while fetching another page.
  final String? loadMoreError;

  bool get isLoading => phase == FlightsPhase.loading;

  bool get hasError => phase == FlightsPhase.failure;

  bool get hasData => phase == FlightsPhase.ready;

  bool get hasMore => flights.length < total;

  bool get isEmpty => hasData && flights.isEmpty;

  Airport? airportFor(int airportId) => airports[airportId];

  Airline? airlineFor(int airlineId) => airlines[airlineId];

  String? airlineNameFor(Flight flight) {
    if (flight.airlineId != null) {
      return airlines[flight.airlineId]?.name;
    }

    return flight.airlineName;
  }
}
