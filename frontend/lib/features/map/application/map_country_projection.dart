import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_repository.dart';
import '../../residences/domain/residence.dart';
import '../../wishlist/domain/wishlist_entry.dart';
import '../domain/map_country_data.dart';

/// Builds a read-only geographic projection of the user's travel records.
///
/// This class does not create or modify visits, residences, wishlist entries,
/// or Trip associations.
class MapCountryProjection {
  const MapCountryProjection({required CityRepository cityRepository})
    : _cityRepository = cityRepository;

  static const _cityResolutionBatchSize = 200;

  final CityRepository _cityRepository;

  Future<MapCountryData> build({
    required List<CountryVisit> visits,
    required List<Residence> residences,
    required List<WishlistEntry> wishlistEntries,
  }) async {
    // -----------------------------------------------------------------------
    // 1. Visited countries
    // -----------------------------------------------------------------------

    final visitedCountryCodes = <String>{
      for (final visit in visits) visit.countryCode,
    };

    // -----------------------------------------------------------------------
    // 2. Countries where the user lived
    // -----------------------------------------------------------------------

    // City residences already contain their country code.
    //
    // Do not create a Country Visit from a Residence.
    final livedCountryCodes = <String>{
      for (final residence in residences) residence.countryCode,
    };

    // -----------------------------------------------------------------------
    // 3. Countries explicitly added to the wishlist
    // -----------------------------------------------------------------------

    final wishlistCountryCodes = <String>{
      for (final entry in wishlistEntries)
        if (entry.countryCode case final String countryCode) countryCode,
    };
    final cityWishlistCountryCodes = <String>{};

    // -----------------------------------------------------------------------
    // 4. Cities added to the wishlist
    // -----------------------------------------------------------------------

    final wishlistCityIds = <int>{
      for (final entry in wishlistEntries)
        if (entry.cityId case final int cityId) cityId,
    }.toList();

    // CityRepository.resolveByIds accepts at most 200 IDs per request.
    //
    // Resolve larger collections in batches rather than silently omitting
    // destinations or exceeding the API contract.
    for (
      var offset = 0;
      offset < wishlistCityIds.length;
      offset += _cityResolutionBatchSize
    ) {
      final end = (offset + _cityResolutionBatchSize).clamp(
        0,
        wishlistCityIds.length,
      );

      final batch = wishlistCityIds.sublist(offset, end);

      final cities = await _cityRepository.resolveByIds(cityIds: batch);

      for (final city in cities) {
        wishlistCountryCodes.add(city.countryCode);
        cityWishlistCountryCodes.add(city.countryCode);
      }
    }

    // -----------------------------------------------------------------------
    // 5. Immutable projection
    // -----------------------------------------------------------------------

    return MapCountryData(
      visitedCountryCodes: visitedCountryCodes,
      livedCountryCodes: livedCountryCodes,
      wishlistCountryCodes: wishlistCountryCodes,
      cityWishlistCountryCodes: cityWishlistCountryCodes,
    );
  }
}
