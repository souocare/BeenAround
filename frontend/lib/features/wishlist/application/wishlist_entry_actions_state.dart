import '../domain/wishlist_entry.dart';

enum WishlistEntryActionPhase { idle, submitting, success, failure }

enum WishlistEntryAction { updateNote, delete }

class WishlistEntryActionsState {
  const WishlistEntryActionsState({
    this.phase = WishlistEntryActionPhase.idle,
    this.action,
    this.updatedEntry,
    this.deletedEntryId,
    this.errorMessage,
  });

  final WishlistEntryActionPhase phase;
  final WishlistEntryAction? action;

  /// Entry returned by the backend after a successful note update.
  final WishlistEntry? updatedEntry;

  /// ID of the entry successfully removed.
  final String? deletedEntryId;

  final String? errorMessage;

  bool get isSubmitting => phase == WishlistEntryActionPhase.submitting;

  bool get isSuccess => phase == WishlistEntryActionPhase.success;

  bool get noteUpdated =>
      isSuccess &&
      action == WishlistEntryAction.updateNote &&
      updatedEntry != null;

  bool get entryDeleted =>
      isSuccess &&
      action == WishlistEntryAction.delete &&
      deletedEntryId != null;
}
