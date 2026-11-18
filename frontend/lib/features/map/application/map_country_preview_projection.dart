import '../../explore/domain/country.dart';
import '../../explore/domain/country_visit.dart';
import '../../residences/domain/residence.dart';
import '../../wishlist/domain/wishlist_entry.dart';

import '../domain/map_country_data.dart';
import '../domain/map_country_preview.dart';

/// Builds a read-only preview of a country using existing travel records.
///
/// Only explicit country visits count as visits.
/// City residences contribute to residenceCount.
/// Wishlist entries never create visits or residences.
MapCountryPreview buildMapCountryPreview({
  required Country country,
  required List<CountryVisit> visits,
  required List<Residence> residences,
  required List<WishlistEntry> wishlistEntries,
  required MapCountryData countryData,
}) {
  final countryCode = country.code;

  final visitCount = visits
      .where((visit) => visit.countryCode == countryCode)
      .length;

  final residenceCount = residences
      .where((residence) => residence.countryCode == countryCode)
      .length;

  final isCountryWishlisted = wishlistEntries.any(
    (entry) => entry.countryCode == countryCode,
  );

  final hasWishlistedCities = countryData.cityWishlistCountryCodes.contains(
    countryCode,
  );

  return MapCountryPreview(
    countryCode: countryCode,
    countryName: country.name,
    visitCount: visitCount,
    residenceCount: residenceCount,
    isCountryWishlisted: isCountryWishlisted,
    hasWishlistedCities: hasWishlistedCities,
  );
}
