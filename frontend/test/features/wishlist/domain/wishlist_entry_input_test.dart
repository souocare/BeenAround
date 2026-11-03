import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';

void main() {
  group('WishlistEntryInput', () {
    test('serializes a country destination', () {
      final input = WishlistEntryInput.country(
        countryCode: ' pt ',
        note: ' Explore the Douro Valley. ',
      );

      expect(input.toJson(), {
        'country_code': 'PT',
        'note': 'Explore the Douro Valley.',
      });
    });

    test('serializes a city destination with its country', () {
      final input = WishlistEntryInput.city(
        cityId: 123,
        includeCountry: true,
        note: 'Visit the historic center.',
      );

      expect(input.toJson(), {
        'city_id': 123,
        'include_country': true,
        'note': 'Visit the historic center.',
      });
    });

    test('does not include a country without explicit selection', () {
      final input = WishlistEntryInput.city(cityId: 123);

      expect(input.toJson()['include_country'], false);
    });

    test('normalizes blank notes to null', () {
      final input = WishlistEntryInput.country(countryCode: 'PT', note: '   ');

      expect(input.note, isNull);
      expect(input.toJson()['note'], isNull);
    });

    test('rejects invalid country codes', () {
      expect(
        () => WishlistEntryInput.country(countryCode: 'PORTUGAL'),
        throwsArgumentError,
      );

      expect(
        () => WishlistEntryInput.country(countryCode: 'P1'),
        throwsArgumentError,
      );
    });

    test('rejects invalid city IDs', () {
      expect(() => WishlistEntryInput.city(cityId: 0), throwsArgumentError);
    });

    test('rejects notes longer than 1000 characters', () {
      expect(
        () => WishlistEntryInput.country(countryCode: 'PT', note: 'A' * 1001),
        throwsArgumentError,
      );
    });

    test('accepts notes with exactly 1000 characters', () {
      final input = WishlistEntryInput.country(
        countryCode: 'PT',
        note: 'A' * 1000,
      );

      expect(input.note?.length, 1000);
    });
  });
}
