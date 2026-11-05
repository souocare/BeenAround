enum AddCountryVisitPhase {
  idle,
  submitting,
  associating,
  success,
  associationFailure,
  failure,
}

class AddCountryVisitState {
  const AddCountryVisitState({
    this.phase = AddCountryVisitPhase.idle,
    this.errorMessage,
    this.createdVisitId,
    this.selectedTripId,
  });

  final AddCountryVisitPhase phase;

  final String? errorMessage;

  /// ID of a visit successfully created in the global travel history.
  ///
  /// Retained when its optional Trip association fails, allowing
  /// the association to be retried without recreating the visit.
  final String? createdVisitId;

  /// Trip explicitly selected during visit registration.
  final String? selectedTripId;

  bool get isSubmitting =>
      phase == AddCountryVisitPhase.submitting ||
      phase == AddCountryVisitPhase.associating;

  bool get isSuccess => phase == AddCountryVisitPhase.success;

  bool get hasCreatedVisit => createdVisitId != null;

  bool get hasAssociationFailure =>
      phase == AddCountryVisitPhase.associationFailure;
}
