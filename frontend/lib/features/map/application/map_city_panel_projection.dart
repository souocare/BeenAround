import '../domain/map_city_data.dart';
import '../domain/map_search_destination.dart';

/// Presentation data for a selected geographic city.
///
/// City identity may originate from the shared geographic catalog
/// or the user's existing Map projection.
///
/// Personal travel history is optional.
///
/// This projection is read-only and independent of Flutter widgets.
class MapCityPanelData {
  const MapCityPanelData({
    required this.cityId,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.visitCount,
    required this.residenceCount,
    required this.isWishlisted,
  });

  final int cityId;

  final String name;

  final String? countryCode;
  final String countryName;

  final int visitCount;
  final int residenceCount;
  final bool isWishlisted;

  bool get hasVisited => visitCount > 0;
  bool get hasLived => residenceCount > 0;

  bool get hasTravelHistory => hasVisited || hasLived;

  bool get hasAnyStatus => hasVisited || hasLived || isWishlisted;
}

/// Builds presentation data for a selected city.
///
/// When personal city data exists, it is authoritative for
/// visits, residences, and wishlist status.
///
/// Catalog destinations provide geographic identity for
/// cities without personal travel records.
MapCityPanelData? buildMapCityPanelData({
  required MapCityData? city,
  required MapSearchDestination? destination,
}) {
  if (city != null) {
    return MapCityPanelData(
      cityId: city.cityId,
      name: city.name,
      countryCode: city.countryCode,
      countryName: city.countryName,
      visitCount: city.visitCount,
      residenceCount: city.residenceCount,
      isWishlisted: city.isWishlisted,
    );
  }

  if (destination?.type != MapSearchDestinationType.city) {
    return null;
  }

  final rawId = destination!.id;

  if (!rawId.startsWith('city:')) {
    return null;
  }

  final cityId = int.tryParse(rawId.substring('city:'.length));

  if (cityId == null || cityId <= 0) {
    return null;
  }

  return MapCityPanelData(
    cityId: cityId,
    name: destination.title,
    countryCode: destination.countryCode,
    countryName: destination.subtitle,
    visitCount: 0,
    residenceCount: 0,
    isWishlisted: false,
  );
}
