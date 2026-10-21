enum DeleteCountryVisitPhase { idle, deleting, success, failure }

class DeleteCountryVisitState {
  const DeleteCountryVisitState({
    this.phase = DeleteCountryVisitPhase.idle,
    this.errorMessage,
  });

  final DeleteCountryVisitPhase phase;
  final String? errorMessage;

  bool get isDeleting => phase == DeleteCountryVisitPhase.deleting;
}
