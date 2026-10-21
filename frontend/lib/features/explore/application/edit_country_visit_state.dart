enum EditCountryVisitPhase { idle, submitting, success, failure }

class EditCountryVisitState {
  const EditCountryVisitState({
    this.phase = EditCountryVisitPhase.idle,
    this.errorMessage,
  });

  final EditCountryVisitPhase phase;
  final String? errorMessage;

  bool get isSubmitting => phase == EditCountryVisitPhase.submitting;
}
