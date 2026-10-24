enum EditCityVisitPhase { idle, submitting, success, failure }

class EditCityVisitState {
  const EditCityVisitState({
    this.phase = EditCityVisitPhase.idle,
    this.errorMessage,
  });

  final EditCityVisitPhase phase;
  final String? errorMessage;

  bool get isSubmitting => phase == EditCityVisitPhase.submitting;
}
