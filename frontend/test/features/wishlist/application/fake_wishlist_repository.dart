import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';

class FakeWishlistRepository implements WishlistRepository {
  List<WishlistEntry> entries = [];
  Object? error;

  Future<List<WishlistEntry>> Function()? loadHandler;

  int loadCalls = 0;

  @override
  Future<List<WishlistEntry>> getWishlistEntries() {
    loadCalls++;

    if (loadHandler != null) {
      return loadHandler!();
    }

    if (error != null) {
      return Future.error(error!);
    }

    return Future.value(entries);
  }

  @override
  Future<WishlistEntry> getWishlistEntry({required String entryId}) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWishlistEntry({required String entryId}) {
    throw UnimplementedError();
  }
}
