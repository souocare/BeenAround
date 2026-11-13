import '../domain/airline.dart';
import '../domain/airport.dart';
import '../domain/flight.dart';
import '../domain/flight_timing.dart';

enum FlightDetailsPhase { initial, loading, ready, failure }

/// Immutable state of a single personal flight.
///
/// The flight and its backend-calculated timing are loaded
/// together. Aviation catalog metadata is resolved separately
/// and must never prevent the flight from being displayed.
class FlightDetailsState {
  const FlightDetailsState({
    this.phase = FlightDetailsPhase.initial,
    this.flight,
    this.timing,
    this.departureAirport,
    this.arrivalAirport,
    this.airline,
    this.errorMessage,
  });

  final FlightDetailsPhase phase;

  final Flight? flight;

  /// Backend-calculated timing for the selected flight.
  final FlightTiming? timing;

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
