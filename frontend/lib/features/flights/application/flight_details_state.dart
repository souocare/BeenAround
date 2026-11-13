import '../domain/airline.dart';
import '../domain/airport.dart';
import '../domain/flight.dart';

enum FlightDetailsPhase { initial, loading, ready, failure }

/// Immutable state of a single personal flight.
///
/// Missing aviation catalog metadata must not prevent
/// displaying the flight itself.
class FlightDetailsState {
  const FlightDetailsState({
    this.phase = FlightDetailsPhase.initial,
    this.flight,
    this.departureAirport,
    this.arrivalAirport,
    this.airline,
    this.errorMessage,
  });

  final FlightDetailsPhase phase;

  final Flight? flight;

  final Airport? departureAirport;
  final Airport? arrivalAirport;

  final Airline? airline;

  final String? errorMessage;

  bool get isLoading => phase == FlightDetailsPhase.loading;

  bool get isReady => phase == FlightDetailsPhase.ready;

  bool get hasError => phase == FlightDetailsPhase.failure;

  String? get airlineName {
    final currentFlight = flight;

    if (currentFlight == null) {
      return null;
    }

    return airline?.name ?? currentFlight.airlineName;
  }
}
