import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/residence_repository.dart';
import 'delete_residence_state.dart';

/// Coordinates explicit deletion of a historical residence.
///
/// UI confirmation must happen before calling deleteResidence().
///
/// The backend remains responsible for authorization and persistence.
class DeleteResidenceCubit extends Cubit<DeleteResidenceState> {
  DeleteResidenceCubit({required ResidenceRepository repository})
    : _repository = repository,
      super(const DeleteResidenceState());

  final ResidenceRepository _repository;

  /// Delete a residence explicitly selected by the user.
  ///
  /// Returns true only after the backend confirms successful deletion.
  Future<bool> deleteResidence({required String residenceId}) async {
    if (isClosed || state.isDeleting || state.isSuccess) {
      return false;
    }

    final id = residenceId.trim();

    if (id.isEmpty) {
      emit(
        const DeleteResidenceState(
          phase: DeleteResidencePhase.failure,
          errorMessage: 'Invalid residence identifier.',
        ),
      );

      return false;
    }

    emit(const DeleteResidenceState(phase: DeleteResidencePhase.deleting));

    try {
      await _repository.deleteResidence(residenceId: id);

      if (isClosed) return false;

      emit(
        DeleteResidenceState(
          phase: DeleteResidencePhase.success,
          deletedResidenceId: id,
        ),
      );

      return true;
    } on ApiException catch (error) {
      return _handleFailure(error.message);
    } catch (_) {
      return _handleFailure(
        'Unable to delete your residence. Please try again.',
      );
    }
  }

  bool _handleFailure(String message) {
    if (isClosed) return false;

    emit(
      DeleteResidenceState(
        phase: DeleteResidencePhase.failure,
        errorMessage: message,
      ),
    );

    return false;
  }

  /// Clear a previous failure without repeating the request.
  void clearError() {
    if (isClosed || !state.isFailure) return;

    emit(const DeleteResidenceState());
  }

  /// Prepare the Cubit for another explicit operation.
  ///
  /// A successful deletion cannot be repeated without resetting.
  void reset() {
    if (isClosed || state.isDeleting) return;

    emit(const DeleteResidenceState());
  }
}
