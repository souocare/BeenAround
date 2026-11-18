import 'map_destination_status.dart';

class MapCountryData {
  MapCountryData({
    required Set<String> visitedCountryCodes,
    required Set<String> livedCountryCodes,
    required Set<String> wishlistCountryCodes,
    Set<String> cityWishlistCountryCodes = const {},
  }) : visitedCountryCodes = Set.unmodifiable(visitedCountryCodes),
       livedCountryCodes = Set.unmodifiable(livedCountryCodes),
       wishlistCountryCodes = Set.unmodifiable(wishlistCountryCodes),
       cityWishlistCountryCodes = Set.unmodifiable(cityWishlistCountryCodes);

  final Set<String> visitedCountryCodes;
  final Set<String> livedCountryCodes;

  /// Countries represented in the global wishlist, either directly
  /// or through a city belonging to that country.
  final Set<String> wishlistCountryCodes;

  /// Countries containing at least one wishlisted city.
  ///
  /// This does not imply an explicit country wishlist entry.
  final Set<String> cityWishlistCountryCodes;

  Set<String> countriesFor(MapDestinationStatus status) {
    return switch (status) {
      MapDestinationStatus.visited => visitedCountryCodes,
      MapDestinationStatus.lived => livedCountryCodes,
      MapDestinationStatus.wishlist => wishlistCountryCodes,
    };
  }
}
