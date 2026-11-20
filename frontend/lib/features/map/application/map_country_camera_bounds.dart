import 'dart:convert';
import 'dart:math' as math;

import 'package:maplibre/maplibre.dart';

/// Finds a geographic region for contextual country camera positioning.
///
/// For MultiPolygon countries, prefers the polygon containing the tapped
/// location within its bounding box.
///
/// This avoids fitting distant islands when the user taps the mainland.
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
  final candidateBounds = _extractPolygonBounds(countryGeoJson);

  if (candidateBounds.isEmpty) {
    return null;
  }

  // Prefer the smallest polygon whose bounding rectangle
  // contains the tap.
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

  return _createCameraBounds(
    polygon: candidates.first,
    minimumLatitudeSpan: minimumLatitudeSpan,
    minimumLongitudeSpan: minimumLongitudeSpan,
  );
}

/// Finds a representative geographic region for a country selected
/// through search.
///
/// Unlike map-tap selection, search has no geographic tap position.
///
/// For MultiPolygon countries, the polygon with the largest bounding
/// rectangle is selected as an approximation of the main region.
///
/// This is a geographic heuristic, not a calculation of actual
/// land area. Countries consisting of many islands may require
/// more sophisticated framing in a future iteration.
///
/// Does not modify map state or travel records.
LngLatBounds? calculateCountrySearchCameraBounds({
  required String countryGeoJson,
  double minimumLatitudeSpan = 6,
  double minimumLongitudeSpan = 8,
}) {
  final candidateBounds = _extractPolygonBounds(countryGeoJson);

  if (candidateBounds.isEmpty) {
    return null;
  }

  // Select the largest geographic polygon.
  //
  // This generally favors the mainland over small,
  // geographically distant territories.
  final selected = candidateBounds.reduce(
    (largest, candidate) => candidate.area > largest.area ? candidate : largest,
  );

  return _createCameraBounds(
    polygon: selected,
    minimumLatitudeSpan: minimumLatitudeSpan,
    minimumLongitudeSpan: minimumLongitudeSpan,
  );
}

/// Extracts individual polygon bounds from a GeoJSON FeatureCollection.
///
/// Both map-tap and search camera calculations use this function.
List<_PolygonBounds> _extractPolygonBounds(String countryGeoJson) {
  final decoded = jsonDecode(countryGeoJson);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid country GeoJSON.');
  }

  final features = decoded['features'];

  if (features is! List || features.isEmpty) {
    return [];
  }

  final candidateBounds = <_PolygonBounds>[];

  for (final feature in features) {
    if (feature is! Map) {
      continue;
    }

    final geometry = feature['geometry'];

    if (geometry is! Map) {
      continue;
    }

    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (coordinates is! List) {
      continue;
    }

    if (type == 'Polygon') {
      final bounds = _boundsForPolygon(coordinates);

      if (bounds != null) {
        candidateBounds.add(bounds);
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        if (polygon is! List) {
          continue;
        }

        final bounds = _boundsForPolygon(polygon);

        if (bounds != null) {
          candidateBounds.add(bounds);
        }
      }
    }
  }

  return candidateBounds;
}

/// Applies minimum geographic dimensions to the selected polygon.
///
/// Both camera-selection strategies use identical framing rules.
LngLatBounds _createCameraBounds({
  required _PolygonBounds polygon,
  required double minimumLatitudeSpan,
  required double minimumLongitudeSpan,
}) {
  final centerLatitude = (polygon.south + polygon.north) / 2;
  final centerLongitude = (polygon.west + polygon.east) / 2;

  final latitudeSpan = math.max(
    polygon.north - polygon.south,
    minimumLatitudeSpan,
  );

  final longitudeSpan = math.max(
    polygon.east - polygon.west,
    minimumLongitudeSpan,
  );

  return LngLatBounds(
    latitudeSouth: math.max(-85, centerLatitude - latitudeSpan / 2),
    latitudeNorth: math.min(85, centerLatitude + latitudeSpan / 2),
    longitudeWest: math.max(-180, centerLongitude - longitudeSpan / 2),
    longitudeEast: math.min(180, centerLongitude + longitudeSpan / 2),
  );
}

/// Calculates the geographic bounding rectangle of a polygon.
_PolygonBounds? _boundsForPolygon(List<dynamic> rings) {
  double? west;
  double? east;
  double? south;
  double? north;

  for (final ring in rings) {
    if (ring is! List) {
      continue;
    }

    for (final coordinate in ring) {
      if (coordinate is! List || coordinate.length < 2) {
        continue;
      }

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is! num || latitude is! num) {
        continue;
      }

      final lon = longitude.toDouble();
      final lat = latitude.toDouble();

      if (!lon.isFinite || !lat.isFinite) {
        continue;
      }

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

/// Geographic bounding rectangle of an individual polygon.
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

  /// Approximate geographic area based on the bounding rectangle.
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
