import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/residence.dart';
import '../domain/residence_changes.dart';
import '../domain/residence_input.dart';
import '../domain/residence_overlap.dart';
import '../domain/residence_repository.dart';

import 'save_residence_state.dart';

/// Coordinates explicit creation and editing of historical residences.
///
/// Overlap confirmations are never submitted automatically.
class SaveResidenceCubit extends Cubit<SaveResidenceState> {
  SaveResidenceCubit({required ResidenceRepository repository})
    : _repository = repository,
      super(const SaveResidenceState());

  final ResidenceRepository _repository;

  /// Create a historical residence.
  ///
  /// Returns true only when the backend persists the residence.
  Future<bool> create({required ResidenceInput input}) async {
    if (!_canSubmit) return false;

    // Starting a new submission invalidates any previous proposal.
    emit(const SaveResidenceState(phase: SaveResidencePhase.submitting));

    return _executeCreate(input: input);
  }

  /// Update an existing historical residence.
  ///
  /// The repository remains responsible for request serialization.
  Future<bool> update({
    required String residenceId,
    required ResidenceChanges changes,
  }) async {
    if (!_canSubmit) return false;

    emit(const SaveResidenceState(phase: SaveResidencePhase.submitting));

    return _executeUpdate(residenceId: residenceId, changes: changes);
  }

  /// Explicitly accept the currently pending overlap proposal.
  ///
  /// This method never accepts replacement form values.
  ///
  /// The original request is reused exactly as submitted when the
  /// backend generated the proposal.
  Future<bool> confirmOverlap() async {
    if (isClosed || state.isSubmitting || !state.requiresConfirmation) {
      return false;
    }

    final pending = state.pendingSave!;

    emit(const SaveResidenceState(phase: SaveResidencePhase.submitting));

    if (pending.isCreate) {
      return _executeCreate(
        input: pending.input!,
        confirmation: pending.proposal,
      );
    }

    return _executeUpdate(
      residenceId: pending.residenceId!,
      changes: pending.changes!,
      confirmation: pending.proposal,
    );
  }

  /// Discard a pending overlap proposal without saving anything.
  void dismissOverlap() {
    if (isClosed || !state.requiresConfirmation) return;

    emit(const SaveResidenceState());
  }

  /// Clear a previous failure or stale-confirmation message.
  void clearError() {
    if (isClosed) return;

    if (state.phase != SaveResidencePhase.failure &&
        state.phase != SaveResidencePhase.stale) {
      return;
    }

    emit(const SaveResidenceState());
  }

  /// Reset the Cubit when the user intentionally starts a new form.
  ///
  /// A successful submission should not be accidentally repeated
  /// without an explicit reset.
  void reset() {
    if (isClosed || state.isSubmitting) return;

    emit(const SaveResidenceState());
  }

  bool get _canSubmit =>
      !isClosed &&
      !state.isSubmitting &&
      state.phase != SaveResidencePhase.success;

  Future<bool> _executeCreate({
    required ResidenceInput input,
    ResidenceOverlapProposal? confirmation,
  }) async {
    try {
      final residence = await _repository.createResidence(
        input: input,
        overlapConfirmation: confirmation,
      );

      return _handleSuccess(residence);
    } on ResidenceOverlapRequired catch (error) {
      if (isClosed) return false;

      emit(
        SaveResidenceState(
          phase: SaveResidencePhase.overlapRequired,
          pendingSave: PendingResidenceSave.create(
            input: input,
            proposal: error.proposal,
          ),
        ),
      );

      return false;
    } on ResidenceOverlapStale catch (error) {
      return _handleStale(error);
    } on ApiException catch (error) {
      return _handleFailure(error.message);
    } catch (_) {
      return _handleFailure('Unable to save your residence. Please try again.');
    }
  }

  Future<bool> _executeUpdate({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? confirmation,
  }) async {
    try {
      final residence = await _repository.updateResidence(
        residenceId: residenceId,
        changes: changes,
        overlapConfirmation: confirmation,
      );

      return _handleSuccess(residence);
    } on ResidenceOverlapRequired catch (error) {
      if (isClosed) return false;

      emit(
        SaveResidenceState(
          phase: SaveResidencePhase.overlapRequired,
          pendingSave: PendingResidenceSave.update(
            residenceId: residenceId,
            changes: changes,
            proposal: error.proposal,
          ),
        ),
      );

      return false;
    } on ResidenceOverlapStale catch (error) {
      return _handleStale(error);
    } on ApiException catch (error) {
      return _handleFailure(error.message);
    } catch (_) {
      return _handleFailure('Unable to save your residence. Please try again.');
    }
  }

  bool _handleSuccess(Residence residence) {
    if (isClosed) return false;

    emit(
      SaveResidenceState(
        phase: SaveResidencePhase.success,
        savedResidence: residence,
      ),
    );

    return true;
  }

  bool _handleStale(ResidenceOverlapStale error) {
    if (isClosed) return false;

    // Never retain an expired overlap confirmation.
    emit(
      SaveResidenceState(
        phase: SaveResidencePhase.stale,
        errorMessage: error.message,
      ),
    );

    return false;
  }

  bool _handleFailure(String message) {
    if (isClosed) return false;

    emit(
      SaveResidenceState(
        phase: SaveResidencePhase.failure,
        errorMessage: message,
      ),
    );

    return false;
  }
}
