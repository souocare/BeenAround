import '../../trips/domain/trip.dart';

enum CountryTripsPhase { initial, loading, ready, failure }

class CountryTripsState {
  const CountryTripsState({
    this.phase = CountryTripsPhase.initial,
    this.trips = const [],
    this.errorMessage,
  });

  final CountryTripsPhase phase;
  final List<Trip> trips;
  final String? errorMessage;

  bool get isInitial => phase == CountryTripsPhase.initial;

  bool get isLoading => phase == CountryTripsPhase.loading;

  bool get isReady => phase == CountryTripsPhase.ready;

  bool get isFailure => phase == CountryTripsPhase.failure;

  int get tripCount => trips.length;

  CountryTripsState copyWith({
    CountryTripsPhase? phase,
    List<Trip>? trips,
    String? errorMessage,
  }) {
    return CountryTripsState(
      phase: phase ?? this.phase,
      trips: trips ?? this.trips,
      errorMessage: errorMessage,
    );
  }
}
