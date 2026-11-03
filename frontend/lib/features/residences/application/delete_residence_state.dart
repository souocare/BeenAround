enum DeleteResidencePhase { idle, deleting, success, failure }

/// State of an explicit historical residence deletion.
class DeleteResidenceState {
  const DeleteResidenceState({
    this.phase = DeleteResidencePhase.idle,
    this.deletedResidenceId,
    this.errorMessage,
  });

  final DeleteResidencePhase phase;

  /// Identifier of the residence successfully deleted.
  ///
  /// Only populated after the backend confirms deletion.
  final String? deletedResidenceId;

  final String? errorMessage;

  bool get isDeleting => phase == DeleteResidencePhase.deleting;

  bool get isSuccess => phase == DeleteResidencePhase.success;

  bool get isFailure => phase == DeleteResidencePhase.failure;

  bool get wasDeleted => isSuccess && deletedResidenceId != null;
}
