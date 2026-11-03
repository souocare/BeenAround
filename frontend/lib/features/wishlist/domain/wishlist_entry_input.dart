/// Input for explicitly adding a destination to the global wishlist.
///
/// Exactly one of countryCode or cityId must be supplied.
class WishlistEntryInput {
  WishlistEntryInput.country({required String countryCode, String? note})
    : this._(
        countryCode: countryCode,
        cityId: null,
        includeCountry: false,
        note: note,
      );

  WishlistEntryInput.city({
    required int cityId,
    bool includeCountry = false,
    String? note,
  }) : this._(
         countryCode: null,
         cityId: cityId,
         includeCountry: includeCountry,
         note: note,
       );

  WishlistEntryInput._({
    required this.countryCode,
    required this.cityId,
    required this.includeCountry,
    required String? note,
  }) : note = _normalizeNote(note) {
    if ((countryCode == null) == (cityId == null)) {
      throw ArgumentError('Exactly one wishlist destination must be provided.');
    }

    final code = countryCode;

    if (code != null) {
      final normalized = code.trim().toUpperCase();

      if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
        throw ArgumentError.value(
          code,
          'countryCode',
          'Expected a two-letter country code.',
        );
      }
    }

    final selectedCityId = cityId;

    if (selectedCityId != null && selectedCityId <= 0) {
      throw ArgumentError.value(
        selectedCityId,
        'cityId',
        'Expected a positive city ID.',
      );
    }
  }

  final String? countryCode;
  final int? cityId;
  final bool includeCountry;
  final String? note;

  Map<String, dynamic> toJson() {
    if (countryCode != null) {
      return {'country_code': countryCode!.trim().toUpperCase(), 'note': note};
    }

    return {'city_id': cityId, 'include_country': includeCountry, 'note': note};
  }

  static String? _normalizeNote(String? value) {
    if (value == null) return null;

    if (value.length > 1000) {
      throw ArgumentError.value(
        value,
        'note',
        'A wishlist note cannot exceed 1000 characters.',
      );
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
