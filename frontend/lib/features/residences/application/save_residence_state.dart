import '../domain/residence.dart';
import '../domain/residence_changes.dart';
import '../domain/residence_input.dart';
import '../domain/residence_overlap.dart';

enum SaveResidencePhase {
  idle,
  submitting,
  overlapRequired,
  success,
  stale,
  failure,
}

enum ResidenceSaveOperation { create, update }

/// The exact operation awaiting explicit overlap confirmation.
///
/// Keeping the original input prevents a confirmation from being
/// accidentally applied to a different form submission.
class PendingResidenceSave {
  const PendingResidenceSave.create({
    required ResidenceInput input,
    required this.proposal,
  }) : operation = ResidenceSaveOperation.create,
       input = input,
       residenceId = null,
       changes = null;

  const PendingResidenceSave.update({
    required String residenceId,
    required ResidenceChanges changes,
    required this.proposal,
  }) : operation = ResidenceSaveOperation.update,
       input = null,
       residenceId = residenceId,
       changes = changes;

  final ResidenceSaveOperation operation;

  final ResidenceInput? input;

  final String? residenceId;
  final ResidenceChanges? changes;

  final ResidenceOverlapProposal proposal;

  bool get isCreate => operation == ResidenceSaveOperation.create;

  bool get isUpdate => operation == ResidenceSaveOperation.update;
}

class SaveResidenceState {
  const SaveResidenceState({
    this.phase = SaveResidencePhase.idle,
    this.savedResidence,
    this.pendingSave,
    this.errorMessage,
  });

  final SaveResidencePhase phase;

  /// Residence returned by the backend after a successful save.
  final Residence? savedResidence;

  /// Original operation and proposal awaiting user confirmation.
  final PendingResidenceSave? pendingSave;

  final String? errorMessage;

  bool get isSubmitting => phase == SaveResidencePhase.submitting;

  bool get isSuccess => phase == SaveResidencePhase.success;

  bool get requiresConfirmation =>
      phase == SaveResidencePhase.overlapRequired && pendingSave != null;

  ResidenceOverlapProposal? get pendingProposal => pendingSave?.proposal;
}
