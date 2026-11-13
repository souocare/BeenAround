enum DeleteFlightPhase { initial, deleting, success, failure }

/// State of a single personal-flight deletion.
class DeleteFlightState {
  const DeleteFlightState({
    this.phase = DeleteFlightPhase.initial,
    this.errorMessage,
  });

  final DeleteFlightPhase phase;
  final String? errorMessage;

  bool get isDeleting => phase == DeleteFlightPhase.deleting;

  bool get isSuccess => phase == DeleteFlightPhase.success;

  bool get hasError => phase == DeleteFlightPhase.failure;
}
