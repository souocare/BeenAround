import '../domain/trip.dart';

enum SaveTripPhase { initial, submitting, success, failure }

/// State of a Trip creation or editing operation.
class SaveTripState {
  const SaveTripState({
    this.phase = SaveTripPhase.initial,
    this.trip,
    this.errorMessage,
  });

  final SaveTripPhase phase;

  /// The persisted Trip returned by the API after a successful save.
  final Trip? trip;

  final String? errorMessage;

  bool get isSubmitting => phase == SaveTripPhase.submitting;

  bool get isSuccess => phase == SaveTripPhase.success;

  bool get hasError => phase == SaveTripPhase.failure;
}
