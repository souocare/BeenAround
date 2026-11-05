import '../domain/trip.dart';

enum TripDetailsPhase { initial, loading, ready, failure }

class TripDetailsState {
  const TripDetailsState({
    this.phase = TripDetailsPhase.initial,
    this.trip,
    this.errorMessage,
  });

  final TripDetailsPhase phase;
  final Trip? trip;
  final String? errorMessage;

  bool get isLoading => phase == TripDetailsPhase.loading;
  bool get hasData => trip != null;
  bool get hasError => phase == TripDetailsPhase.failure;
}
