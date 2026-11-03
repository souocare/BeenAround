import 'residence.dart';
import 'residence_changes.dart';
import 'residence_input.dart';
import 'residence_overlap.dart';

/// Operations supported for the authenticated user's historical residences.
abstract interface class ResidenceRepository {
  Future<List<Residence>> getResidences();

  Future<Residence> getResidence({required String residenceId});

  /// Creates a historical residence.
  ///
  /// An overlap confirmation must only be supplied after the user
  /// explicitly approves the proposal returned by the backend.
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  });

  /// Updates an existing historical residence.
  ///
  /// Omitted fields preserve their existing values.
  /// Explicitly setting note to null removes the note.
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  });

  Future<void> deleteResidence({required String residenceId});
}
