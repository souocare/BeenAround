import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/wishlist_repository.dart';
import 'wishlist_entry_actions_state.dart';

/// Coordinates explicit changes to an existing wishlist entry.
///
/// The backend remains responsible for authorization and persistence.
class WishlistEntryActionsCubit extends Cubit<WishlistEntryActionsState> {
  WishlistEntryActionsCubit({required WishlistRepository repository})
    : _repository = repository,
      super(const WishlistEntryActionsState());

  final WishlistRepository _repository;

  Future<bool> updateNote({
    required String entryId,
    required String? note,
  }) async {
    if (!_canSubmit) return false;

    emit(
      const WishlistEntryActionsState(
        phase: WishlistEntryActionPhase.submitting,
        action: WishlistEntryAction.updateNote,
      ),
    );

    try {
      final entry = await _repository.updateWishlistNote(
        entryId: entryId,
        note: note,
      );

      if (isClosed) return false;

      emit(
        WishlistEntryActionsState(
          phase: WishlistEntryActionPhase.success,
          action: WishlistEntryAction.updateNote,
          updatedEntry: entry,
        ),
      );

      return true;
    } on ApiException catch (error) {
      return _handleFailure(
        action: WishlistEntryAction.updateNote,
        message: error.message,
      );
    } catch (_) {
      return _handleFailure(
        action: WishlistEntryAction.updateNote,
        message: 'Unable to update the wishlist note. Please try again.',
      );
    }
  }

  Future<bool> deleteEntry({required String entryId}) async {
    if (!_canSubmit) return false;

    emit(
      const WishlistEntryActionsState(
        phase: WishlistEntryActionPhase.submitting,
        action: WishlistEntryAction.delete,
      ),
    );

    try {
      await _repository.deleteWishlistEntry(entryId: entryId);

      if (isClosed) return false;

      emit(
        WishlistEntryActionsState(
          phase: WishlistEntryActionPhase.success,
          action: WishlistEntryAction.delete,
          deletedEntryId: entryId,
        ),
      );

      return true;
    } on ApiException catch (error) {
      return _handleFailure(
        action: WishlistEntryAction.delete,
        message: error.message,
      );
    } catch (_) {
      return _handleFailure(
        action: WishlistEntryAction.delete,
        message: 'Unable to remove the wishlist entry. Please try again.',
      );
    }
  }

  bool _handleFailure({
    required WishlistEntryAction action,
    required String message,
  }) {
    if (isClosed) return false;

    emit(
      WishlistEntryActionsState(
        phase: WishlistEntryActionPhase.failure,
        action: action,
        errorMessage: message,
      ),
    );

    return false;
  }

  bool get _canSubmit => !isClosed && !state.isSubmitting && !state.isSuccess;

  void clearError() {
    if (isClosed || state.phase != WishlistEntryActionPhase.failure) {
      return;
    }

    emit(const WishlistEntryActionsState());
  }

  /// Explicitly prepare the Cubit for another operation.
  void reset() {
    if (isClosed || state.isSubmitting) return;

    emit(const WishlistEntryActionsState());
  }
}
