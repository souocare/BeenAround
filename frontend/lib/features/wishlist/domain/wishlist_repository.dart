import 'wishlist_creation_result.dart';
import 'wishlist_entry.dart';
import 'wishlist_entry_input.dart';

/// Operations supported by the authenticated user's global wishlist.
abstract interface class WishlistRepository {
  Future<List<WishlistEntry>> getWishlistEntries();

  Future<WishlistEntry> getWishlistEntry({required String entryId});

  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  });

  /// Updates or clears the note of an existing wishlist entry.
  ///
  /// Passing null explicitly clears the note.
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  });

  Future<void> deleteWishlistEntry({required String entryId});
}
