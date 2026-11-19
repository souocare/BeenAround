import '../../geography/domain/city_visit.dart';
import '../../geography/domain/city_repository.dart';
import '../../residences/domain/residence.dart';
import '../../wishlist/domain/wishlist_entry.dart';

import '../domain/map_city_data.dart';

/// Builds a geographic projection of cities referenced by
/// the authenticated user's travel records.
///
/// The projection is read-only and does not create visits,
/// residences, wishlist entries or Trip associations.
class MapCityProjection {
  const MapCityProjection({required CityRepository cityRepository})
    : _cityRepository = cityRepository;

  static const int _batchSize = 200;

  final CityRepository _cityRepository;

  Future<Map<int, MapCityData>> build({
    required List<CityVisit> visits,
    required List<Residence> residences,
    required List<WishlistEntry> wishlistEntries,
  }) async {
    // ---------------------------------------------------------
    // 1. Count recorded city visits.
    // ---------------------------------------------------------

    final visitCounts = <int, int>{};

    for (final visit in visits) {
      visitCounts.update(visit.cityId, (count) => count + 1, ifAbsent: () => 1);
    }

    // ---------------------------------------------------------
    // 2. Count city residence periods.
    //
    // Country-only residences must not create city markers.
    // ---------------------------------------------------------

    final residenceCounts = <int, int>{};

    for (final residence in residences) {
      final cityId = residence.cityId;

      if (cityId == null) {
        continue;
      }

      residenceCounts.update(cityId, (count) => count + 1, ifAbsent: () => 1);
    }

    // ---------------------------------------------------------
    // 3. Identify explicitly wishlisted cities.
    //
    // Country wishlist entries are intentionally excluded.
    // ---------------------------------------------------------

    final wishlistCityIds = <int>{
      for (final entry in wishlistEntries)
        if (entry.cityId case final int cityId) cityId,
    };

    // ---------------------------------------------------------
    // 4. Combine unique city IDs.
    // ---------------------------------------------------------

    final cityIds = <int>{
      ...visitCounts.keys,
      ...residenceCounts.keys,
      ...wishlistCityIds,
    }.toList()..sort();

    if (cityIds.isEmpty) {
      return const <int, MapCityData>{};
    }

    // ---------------------------------------------------------
    // 5. Resolve geographic catalog entries in batches.
    //
    // CityRepository.resolveByIds accepts at most 200 IDs.
    // ---------------------------------------------------------

    final result = <int, MapCityData>{};

    for (var offset = 0; offset < cityIds.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, cityIds.length);

      final batch = cityIds.sublist(offset, end);

      final cities = await _cityRepository.resolveByIds(cityIds: batch);

      for (final city in cities) {
        // Ignore catalog records without valid geographic
        // coordinates. Never guess a city's location.
        if (!_hasValidCoordinates(city.latitude, city.longitude)) {
          continue;
        }

        result[city.id] = MapCityData(
          cityId: city.id,
          name: city.name,
          countryCode: city.countryCode,
          countryName: city.countryName,
          latitude: city.latitude,
          longitude: city.longitude,
          visitCount: visitCounts[city.id] ?? 0,
          residenceCount: residenceCounts[city.id] ?? 0,
          isWishlisted: wishlistCityIds.contains(city.id),
        );
      }
    }

    // ---------------------------------------------------------
    // 6. Return an immutable geographic projection.
    // ---------------------------------------------------------

    return Map<int, MapCityData>.unmodifiable(result);
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
