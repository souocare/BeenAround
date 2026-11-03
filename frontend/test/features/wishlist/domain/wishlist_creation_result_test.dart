import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';

void main() {
  Map<String, dynamic> entryJson({
    required String id,
    String? countryCode,
    int? cityId,
  }) {
    return {
      'id': id,
      'country_code': countryCode,
      'city_id': cityId,
      'note': null,
      'created_at': '2026-11-03T10:00:00Z',
      'updated_at': '2026-11-03T10:00:00Z',
    };
  }

  group('WishlistCreationResult', () {
    test('separates created and existing entries', () {
      final result = WishlistCreationResult.fromJson({
        'created': [entryJson(id: 'city-entry', cityId: 123)],
        'existing': [entryJson(id: 'country-entry', countryCode: 'PT')],
      });

      expect(result.created, hasLength(1));
      expect(result.existing, hasLength(1));

      expect(result.created.first.cityId, 123);
      expect(result.existing.first.countryCode, 'PT');

      expect(result.hasCreatedEntries, isTrue);
      expect(result.allAlreadyExisted, isFalse);
    });

    test('recognizes an entirely existing request', () {
      final result = WishlistCreationResult.fromJson({
        'created': [],
        'existing': [entryJson(id: 'country-entry', countryCode: 'PT')],
      });

      expect(result.created, isEmpty);
      expect(result.allAlreadyExisted, isTrue);
    });

    test('rejects malformed response lists', () {
      expect(
        () => WishlistCreationResult.fromJson({'created': {}, 'existing': []}),
        throwsFormatException,
      );
    });

    test('returns immutable lists', () {
      final result = WishlistCreationResult.fromJson({
        'created': [entryJson(id: 'country-entry', countryCode: 'PT')],
        'existing': [],
      });

      expect(() => result.created.clear(), throwsUnsupportedError);
    });
  });
}
