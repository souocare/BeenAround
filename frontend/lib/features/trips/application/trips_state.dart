import '../domain/trip.dart';

enum TripsPhase { initial, loading, ready, failure }

class TripsState {
  const TripsState({
    this.phase = TripsPhase.initial,
    this.trips = const [],
    this.errorMessage,
  });

  final TripsPhase phase;
  final List<Trip> trips;
  final String? errorMessage;

  bool get hasData => phase == TripsPhase.ready;

  bool get isLoading => phase == TripsPhase.loading;

  bool get hasError => phase == TripsPhase.failure;

  int get totalTrips => trips.length;
}
