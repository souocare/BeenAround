import '../domain/wishlist_creation_result.dart';

enum AddWishlistEntryPhase { idle, submitting, success, failure }

/// State of an explicit wishlist addition.
///
/// The creation result retains the distinction between newly created
/// destinations and destinations that already existed.
class AddWishlistEntryState {
  const AddWishlistEntryState({
    this.phase = AddWishlistEntryPhase.idle,
    this.result,
    this.errorMessage,
  });

  final AddWishlistEntryPhase phase;

  final WishlistCreationResult? result;

  final String? errorMessage;

  bool get isSubmitting => phase == AddWishlistEntryPhase.submitting;

  bool get isSuccess => phase == AddWishlistEntryPhase.success;

  bool get hasCreatedEntries =>
      isSuccess && (result?.created.isNotEmpty ?? false);

  bool get allAlreadyExisted =>
      isSuccess && (result?.allAlreadyExisted ?? false);

  bool get partiallyCreated =>
      isSuccess &&
      (result?.created.isNotEmpty ?? false) &&
      (result?.existing.isNotEmpty ?? false);

  int get createdCount => result?.created.length ?? 0;

  int get existingCount => result?.existing.length ?? 0;
}
