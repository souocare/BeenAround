import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/wishlist_entry_input.dart';
import '../domain/wishlist_repository.dart';
import 'add_wishlist_entry_state.dart';

/// Coordinates explicit additions to the authenticated user's wishlist.
///
/// Duplicate destinations are not treated as errors. The backend returns
/// which entries were created and which already existed.
///
/// The Cubit never automatically retries a successful submission.
class AddWishlistEntryCubit extends Cubit<AddWishlistEntryState> {
  AddWishlistEntryCubit({required WishlistRepository repository})
    : _repository = repository,
      super(const AddWishlistEntryState());

  final WishlistRepository _repository;

  /// Submit an explicit wishlist addition.
  ///
  /// Returns true when the API accepts the request, including when
  /// all requested destinations already existed.
  Future<bool> submit({required WishlistEntryInput input}) async {
    if (isClosed || state.isSubmitting || state.isSuccess) {
      return false;
    }

    emit(const AddWishlistEntryState(phase: AddWishlistEntryPhase.submitting));

    try {
      final result = await _repository.addWishlistEntry(input: input);

      if (isClosed) return false;

      emit(
        AddWishlistEntryState(
          phase: AddWishlistEntryPhase.success,
          result: result,
        ),
      );

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        AddWishlistEntryState(
          phase: AddWishlistEntryPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const AddWishlistEntryState(
          phase: AddWishlistEntryPhase.failure,
          errorMessage: 'Unable to update your wishlist. Please try again.',
        ),
      );

      return false;
    }
  }

  /// Clear a previous error so the form can be submitted again.
  void clearError() {
    if (isClosed || state.phase != AddWishlistEntryPhase.failure) {
      return;
    }

    emit(const AddWishlistEntryState());
  }

  /// Reset after the user explicitly starts another addition.
  ///
  /// A successful request cannot be repeated without resetting.
  void reset() {
    if (isClosed || state.isSubmitting) return;

    emit(const AddWishlistEntryState());
  }
}
