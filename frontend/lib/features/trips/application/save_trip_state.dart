import '../domain/trip.dart';

enum SaveTripPhase { initial, submitting, success, failure, partialFailure }

/// State of a Trip creation or editing operation.
class SaveTripState {
  const SaveTripState({
    this.phase = SaveTripPhase.initial,
    this.trip,
    this.errorMessage,
    this.pendingCountryVisitIds = const [],
    this.pendingCityVisitIds = const [],
  });

  final SaveTripPhase phase;

  /// Persisted Trip, when available.
  ///
  /// In partialFailure, this Trip already exists in the backend.
  final Trip? trip;

  final String? errorMessage;

  /// Associations not yet confirmed as successfully persisted.
  final List<String> pendingCountryVisitIds;
  final List<String> pendingCityVisitIds;

  bool get isSubmitting => phase == SaveTripPhase.submitting;

  bool get isSuccess => phase == SaveTripPhase.success;

  bool get isPartialFailure => phase == SaveTripPhase.partialFailure;

  bool get hasError =>
      phase == SaveTripPhase.failure || phase == SaveTripPhase.partialFailure;

  bool get hasPendingAssociations =>
      pendingCountryVisitIds.isNotEmpty || pendingCityVisitIds.isNotEmpty;
}
