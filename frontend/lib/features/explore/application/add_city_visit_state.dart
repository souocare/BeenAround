import '../../geography/domain/country_visit_date_expansion.dart';
import 'pending_city_visit_creation.dart';

enum AddCityVisitPhase {
  idle,
  submitting,
  expansionRequired,
  associating,
  success,
  associationFailure,
  failure,
}

class AddCityVisitState {
  const AddCityVisitState({
    this.phase = AddCityVisitPhase.idle,
    this.errorMessage,
    this.pendingCreation,
    this.createdVisitId,
    this.selectedTripId,
  });

  final AddCityVisitPhase phase;
  final String? errorMessage;

  /// Original request and proposal awaiting explicit confirmation.
  final PendingCityVisitCreation? pendingCreation;

  /// The successfully created historical visit.
  ///
  /// This remains available if its Trip association fails.
  final String? createdVisitId;

  /// The explicitly selected Trip, if any.
  final String? selectedTripId;

  CountryVisitDateExpansion? get pendingExpansion => pendingCreation?.expansion;

  bool get isSubmitting =>
      phase == AddCityVisitPhase.submitting ||
      phase == AddCityVisitPhase.associating;

  bool get hasCreatedVisit => createdVisitId != null;

  bool get hasAssociationFailure =>
      phase == AddCityVisitPhase.associationFailure;

  bool get isSuccess => phase == AddCityVisitPhase.success;
}
