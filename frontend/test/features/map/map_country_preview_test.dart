import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_country_preview.dart';

void main() {
  group('MapCountryPreview', () {
    test('identifies visited and lived countries', () {
      const preview = MapCountryPreview(
        countryCode: 'PT',
        countryName: 'Portugal',
        visitCount: 3,
        residenceCount: 1,
        isCountryWishlisted: false,
        hasWishlistedCities: false,
      );

      expect(preview.hasVisited, isTrue);
      expect(preview.hasLived, isTrue);
      expect(preview.appearsInWishlist, isFalse);
      expect(preview.hasAnyStatus, isTrue);
    });

    test('distinguishes direct and city wishlist membership', () {
      const preview = MapCountryPreview(
        countryCode: 'ES',
        countryName: 'Spain',
        visitCount: 0,
        residenceCount: 0,
        isCountryWishlisted: true,
        hasWishlistedCities: true,
      );

      expect(preview.isCountryWishlisted, isTrue);
      expect(preview.hasWishlistedCities, isTrue);
      expect(preview.appearsInWishlist, isTrue);
      expect(preview.hasVisited, isFalse);
    });

    test('city wishlist does not imply a country visit', () {
      const preview = MapCountryPreview(
        countryCode: 'JP',
        countryName: 'Japan',
        visitCount: 0,
        residenceCount: 0,
        isCountryWishlisted: false,
        hasWishlistedCities: true,
      );

      expect(preview.hasVisited, isFalse);
      expect(preview.isCountryWishlisted, isFalse);
      expect(preview.appearsInWishlist, isTrue);
    });

    test('identifies a country without travel records', () {
      const preview = MapCountryPreview(
        countryCode: 'FR',
        countryName: 'France',
        visitCount: 0,
        residenceCount: 0,
        isCountryWishlisted: false,
        hasWishlistedCities: false,
      );

      expect(preview.hasAnyStatus, isFalse);
    });
  });
}
