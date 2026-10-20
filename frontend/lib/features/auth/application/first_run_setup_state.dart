import '../data/first_run_setup_repository.dart';

enum FirstRunSetupPhase { idle, submitting, success, failure }

class FirstRunSetupState {
  const FirstRunSetupState({
    this.phase = FirstRunSetupPhase.idle,
    this.failure,
  });

  final FirstRunSetupPhase phase;
  final FirstRunSetupFailure? failure;

  bool get isSubmitting => phase == FirstRunSetupPhase.submitting;
}
