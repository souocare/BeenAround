/// A destination explicitly added to a user's global wishlist.
///
/// A wishlist entry references either a country or a city, never both.
///
/// Wishlist entries exist independently of visits, residences and trips.
class WishlistEntry {
  const WishlistEntry({
    required this.id,
    required this.countryCode,
    required this.cityId,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;

  final String? countryCode;
  final int? cityId;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCountry => countryCode != null;

  bool get isCity => cityId != null;

  factory WishlistEntry.fromJson(Map<String, dynamic> json) {
    final countryCode = json['country_code'] as String?;
    final cityId = json['city_id'] as int?;

    if ((countryCode == null) == (cityId == null)) {
      throw const FormatException(
        'A wishlist entry must contain exactly one destination.',
      );
    }

    return WishlistEntry(
      id: json['id'] as String,
      countryCode: countryCode,
      cityId: cityId,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
