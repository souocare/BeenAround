enum AddCountryVisitPhase { idle, submitting, success, failure }

class AddCountryVisitState {
  const AddCountryVisitState({
    this.phase = AddCountryVisitPhase.idle,
    this.errorMessage,
  });

  final AddCountryVisitPhase phase;
  final String? errorMessage;

  bool get isSubmitting => phase == AddCountryVisitPhase.submitting;
}
