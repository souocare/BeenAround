import '../../trips/domain/trip.dart';

enum CityTripsPhase { initial, loading, ready, failure }

class CityTripsState {
  const CityTripsState({
    this.phase = CityTripsPhase.initial,
    this.trips = const [],
    this.errorMessage,
  });

  final CityTripsPhase phase;
  final List<Trip> trips;
  final String? errorMessage;

  bool get isInitial => phase == CityTripsPhase.initial;

  bool get isLoading => phase == CityTripsPhase.loading;

  bool get isReady => phase == CityTripsPhase.ready;

  bool get isFailure => phase == CityTripsPhase.failure;

  int get tripCount => trips.length;
}
