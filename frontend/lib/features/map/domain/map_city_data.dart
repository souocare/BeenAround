import 'map_destination_status.dart';

/// Read-only geographic representation of one city.
///
/// This is a Map projection, not a persisted domain entity.
///
/// Multiple visits and residence periods for the same city are
/// represented by a single geographic destination.
class MapCityData {
  const MapCityData({
    required this.cityId,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.residenceCount,
    required this.isWishlisted,
  });

  final int cityId;

  final String name;

  final String countryCode;
  final String countryName;

  final double latitude;
  final double longitude;

  /// Number of independently recorded visits to this city.
  final int visitCount;

  /// Number of independently recorded residence periods.
  final int residenceCount;

  /// Whether this city explicitly belongs to the global wishlist.
  final bool isWishlisted;

  bool get isVisited => visitCount > 0;

  bool get isLived => residenceCount > 0;

  /// Whether this city matches the selected visualization status.
  bool matchesStatus(MapDestinationStatus status) {
    switch (status) {
      case MapDestinationStatus.visited:
        return isVisited;

      case MapDestinationStatus.lived:
        return isLived;

      case MapDestinationStatus.wishlist:
        return isWishlisted;
    }
  }
}
