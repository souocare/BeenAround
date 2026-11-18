import 'dart:convert';
import 'dart:math' as math;

import 'package:maplibre/maplibre.dart';

/// Finds a geographic region for contextual country camera positioning.
///
/// For MultiPolygon countries, prefers the polygon containing the tapped
/// location within its bounding box. This avoids fitting distant islands
/// when the user taps the mainland.
///
/// The resulting bounds have a minimum geographic size so that very small
/// countries do not cause excessive zoom.
LngLatBounds? calculateCountryCameraBounds({
  required String countryGeoJson,
  required double tappedLatitude,
  required double tappedLongitude,
  double minimumLatitudeSpan = 6,
  double minimumLongitudeSpan = 8,
}) {
  final decoded = jsonDecode(countryGeoJson);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid country GeoJSON.');
  }

  final features = decoded['features'];

  if (features is! List || features.isEmpty) {
    return null;
  }

  final candidateBounds = <_PolygonBounds>[];

  for (final feature in features) {
    if (feature is! Map) continue;

    final geometry = feature['geometry'];

    if (geometry is! Map) continue;

    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (coordinates is! List) continue;

    if (type == 'Polygon') {
      final bounds = _boundsForPolygon(coordinates);

      if (bounds != null) {
        candidateBounds.add(bounds);
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        if (polygon is! List) continue;

        final bounds = _boundsForPolygon(polygon);

        if (bounds != null) {
          candidateBounds.add(bounds);
        }
      }
    }
  }

  if (candidateBounds.isEmpty) return null;

  // Prefer the smallest polygon whose bounding rectangle contains the tap.
  //
  // This generally identifies the geographic region the user selected,
  // even when the country includes distant islands or territories.
  final containing = candidateBounds
      .where(
        (bounds) => bounds.contains(
          latitude: tappedLatitude,
          longitude: tappedLongitude,
        ),
      )
      .toList();

  final candidates = containing.isNotEmpty ? containing : candidateBounds;

  candidates.sort((a, b) {
    if (containing.isNotEmpty) {
      return a.area.compareTo(b.area);
    }

    return a
        .distanceSquaredTo(latitude: tappedLatitude, longitude: tappedLongitude)
        .compareTo(
          b.distanceSquaredTo(
            latitude: tappedLatitude,
            longitude: tappedLongitude,
          ),
        );
  });

  final selected = candidates.first;

  final centerLatitude = (selected.south + selected.north) / 2;
  final centerLongitude = (selected.west + selected.east) / 2;

  final latitudeSpan = math.max(
    selected.north - selected.south,
    minimumLatitudeSpan,
  );

  final longitudeSpan = math.max(
    selected.east - selected.west,
    minimumLongitudeSpan,
  );

  return LngLatBounds(
    latitudeSouth: math.max(-85, centerLatitude - latitudeSpan / 2),
    latitudeNorth: math.min(85, centerLatitude + latitudeSpan / 2),
    longitudeWest: math.max(-180, centerLongitude - longitudeSpan / 2),
    longitudeEast: math.min(180, centerLongitude + longitudeSpan / 2),
  );
}

_PolygonBounds? _boundsForPolygon(List<dynamic> rings) {
  double? west;
  double? east;
  double? south;
  double? north;

  for (final ring in rings) {
    if (ring is! List) continue;

    for (final coordinate in ring) {
      if (coordinate is! List || coordinate.length < 2) continue;

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is! num || latitude is! num) continue;

      final lon = longitude.toDouble();
      final lat = latitude.toDouble();

      if (!lon.isFinite || !lat.isFinite) continue;

      west = west == null ? lon : math.min(west, lon);
      east = east == null ? lon : math.max(east, lon);
      south = south == null ? lat : math.min(south, lat);
      north = north == null ? lat : math.max(north, lat);
    }
  }

  if (west == null || east == null || south == null || north == null) {
    return null;
  }

  return _PolygonBounds(west: west, east: east, south: south, north: north);
}

class _PolygonBounds {
  const _PolygonBounds({
    required this.west,
    required this.east,
    required this.south,
    required this.north,
  });

  final double west;
  final double east;
  final double south;
  final double north;

  double get area => (east - west) * (north - south);

  bool contains({required double latitude, required double longitude}) {
    return latitude >= south &&
        latitude <= north &&
        longitude >= west &&
        longitude <= east;
  }

  double distanceSquaredTo({
    required double latitude,
    required double longitude,
  }) {
    final nearestLatitude = latitude.clamp(south, north).toDouble();
    final nearestLongitude = longitude.clamp(west, east).toDouble();

    final latitudeDifference = latitude - nearestLatitude;
    final longitudeDifference = longitude - nearestLongitude;

    return latitudeDifference * latitudeDifference +
        longitudeDifference * longitudeDifference;
  }
}
