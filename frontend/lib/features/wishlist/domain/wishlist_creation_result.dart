import 'wishlist_entry.dart';

/// Result of an atomic wishlist creation request.
///
/// Newly created destinations and existing destinations are returned
/// separately so the UI can provide accurate feedback.
class WishlistCreationResult {
  const WishlistCreationResult({required this.created, required this.existing});

  final List<WishlistEntry> created;
  final List<WishlistEntry> existing;

  bool get hasCreatedEntries => created.isNotEmpty;

  bool get allAlreadyExisted => created.isEmpty && existing.isNotEmpty;

  factory WishlistCreationResult.fromJson(Map<String, dynamic> json) {
    final created = json['created'];
    final existing = json['existing'];

    if (created is! List || existing is! List) {
      throw const FormatException('Invalid wishlist creation response.');
    }

    return WishlistCreationResult(
      created: List.unmodifiable(
        created.map(
          (item) =>
              WishlistEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      existing: List.unmodifiable(
        existing.map(
          (item) =>
              WishlistEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
    );
  }
}
