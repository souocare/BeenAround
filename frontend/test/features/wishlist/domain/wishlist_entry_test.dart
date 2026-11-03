import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';

void main() {
  Map<String, dynamic> wishlistJson({
    String? countryCode = 'PT',
    int? cityId,
    String? note,
  }) {
    return {
      'id': 'wishlist-1',
      'country_code': countryCode,
      'city_id': cityId,
      'note': note,
      'created_at': '2026-11-03T10:00:00Z',
      'updated_at': '2026-11-03T10:00:00Z',
    };
  }

  group('WishlistEntry', () {
    test('parses a country wishlist entry', () {
      final entry = WishlistEntry.fromJson(wishlistJson());

      expect(entry.id, 'wishlist-1');
      expect(entry.countryCode, 'PT');
      expect(entry.cityId, isNull);

      expect(entry.isCountry, isTrue);
      expect(entry.isCity, isFalse);
    });

    test('parses a city wishlist entry', () {
      final entry = WishlistEntry.fromJson(
        wishlistJson(countryCode: null, cityId: 123),
      );

      expect(entry.countryCode, isNull);
      expect(entry.cityId, 123);

      expect(entry.isCountry, isFalse);
      expect(entry.isCity, isTrue);
    });

    test('preserves a wishlist note', () {
      final entry = WishlistEntry.fromJson(
        wishlistJson(note: 'Visit during spring.'),
      );

      expect(entry.note, 'Visit during spring.');
    });

    test('accepts a null note', () {
      final entry = WishlistEntry.fromJson(wishlistJson());

      expect(entry.note, isNull);
    });

    test('rejects entries without a destination', () {
      expect(
        () => WishlistEntry.fromJson(
          wishlistJson(countryCode: null, cityId: null),
        ),
        throwsFormatException,
      );
    });

    test('rejects entries with both destinations', () {
      expect(
        () => WishlistEntry.fromJson(
          wishlistJson(countryCode: 'PT', cityId: 123),
        ),
        throwsFormatException,
      );
    });
  });
}
