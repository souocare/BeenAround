import '../data/world_country_loader.dart';

class CountryGeometryBounds {
  const CountryGeometryBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  double get centerLongitude => (west + east) / 2;

  double get centerLatitude => (south + north) / 2;
}

CountryGeometryBounds? calculateCountryBounds(WorldCountryGeometry geometry) {
  double? west;
  double? south;
  double? east;
  double? north;

  for (final polygon in geometry.polygons) {
    for (final ring in polygon) {
      for (final coordinate in ring) {
        final longitude = coordinate[0];
        final latitude = coordinate[1];

        if (!longitude.isFinite || !latitude.isFinite) {
          throw const FormatException('Invalid geographic coordinate');
        }

        if (longitude < -180 ||
            longitude > 180 ||
            latitude < -90 ||
            latitude > 90) {
          throw const FormatException('Coordinate outside geographic bounds');
        }

        if (west == null || longitude < west) west = longitude;
        if (east == null || longitude > east) east = longitude;
        if (south == null || latitude < south) south = latitude;
        if (north == null || latitude > north) north = latitude;
      }
    }
  }

  if (west == null || south == null || east == null || north == null) {
    return null;
  }

  return CountryGeometryBounds(
    west: west,
    south: south,
    east: east,
    north: north,
  );
}
