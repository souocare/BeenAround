enum AddCityVisitPhase { idle, submitting, success, failure }

class AddCityVisitState {
  const AddCityVisitState({
    this.phase = AddCityVisitPhase.idle,
    this.errorMessage,
  });

  final AddCityVisitPhase phase;
  final String? errorMessage;

  bool get isSubmitting => phase == AddCityVisitPhase.submitting;
}
