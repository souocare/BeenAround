enum DeleteCityVisitPhase { idle, deleting, success, failure }

class DeleteCityVisitState {
  const DeleteCityVisitState({
    this.phase = DeleteCityVisitPhase.idle,
    this.errorMessage,
  });

  final DeleteCityVisitPhase phase;
  final String? errorMessage;

  bool get isDeleting => phase == DeleteCityVisitPhase.deleting;
}
