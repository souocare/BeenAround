import 'dart:convert';

import '../../flights/domain/airport.dart';
import '../../flights/domain/flight_route_geometry.dart';

import '../domain/map_flight_route.dart';

/// Builds read-only GeoJSON for unique completed-flight connections.
///
/// Each unique airport pair produces at most one GeoJSON Feature.
///
/// Route geometry:
/// - Reuses the aviation domain's great-circle calculation.
/// - Splits paths at the antimeridian.
/// - Uses MultiLineString consistently.
/// - Skips unresolved or invalid geographic endpoints.
/// - Skips degenerate routes with no drawable geographic extent.
///
/// Flight direction and individual flight records remain in
/// MapFlightRoute, independently of the geographic geometry.
///
/// No repositories, Flutter widgets or MapLibre controllers
/// are accessed.
String buildMapFlightRouteGeoJson({
  required Iterable<MapFlightRoute> routes,
  required Map<int, Airport> airports,
  int segments = FlightRouteGeometry.defaultSegments,
}) {
  if (segments < 1) {
    throw ArgumentError.value(segments, 'segments', 'Must be at least 1.');
  }

  final features = <Map<String, dynamic>>[];

  for (final route in routes) {
    // -----------------------------------------------------------------------
    // Resolve both endpoints from the existing aviation catalog.
    // -----------------------------------------------------------------------

    final firstAirport = airports[route.firstAirportId];
    final secondAirport = airports[route.secondAirportId];

    if (firstAirport == null || secondAirport == null) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Calculate great-circle points.
    //
    // FlightRouteGeometry already validates coordinates and
    // returns an empty collection when they cannot be used.
    // -----------------------------------------------------------------------

    final points = FlightRouteGeometry.between(
      firstAirport,
      secondAirport,
      segments: segments,
    );

    if (points.length < 2) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Reject degenerate routes.
    //
    // Two catalog airports may legitimately share coordinates.
    // Their flight records remain valid, but there is no
    // meaningful line to draw between identical positions.
    // -----------------------------------------------------------------------

    if (_hasNoGeographicExtent(points)) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Split the route at the antimeridian.
    //
    // GeoJSON coordinates use [longitude, latitude].
    // -----------------------------------------------------------------------

    final lines = _splitAtAntimeridian(points);

    if (lines.isEmpty) {
      continue;
    }

    // -----------------------------------------------------------------------
    // Create exactly one feature per unique visual connection.
    //
    // Flight count is deliberately excluded from the styling
    // contract: repeated flights must not change visual weight.
    // -----------------------------------------------------------------------

    features.add({
      'type': 'Feature',
      'properties': {
        'route_id': route.id,
        'first_airport_id': route.firstAirportId,
        'second_airport_id': route.secondAirportId,
      },
      'geometry': {'type': 'MultiLineString', 'coordinates': lines},
    });
  }

  // Stable ordering makes output deterministic even when
  // the caller supplies routes in another order.
  features.sort((a, b) {
    final aProperties = a['properties'] as Map<String, dynamic>;
    final bProperties = b['properties'] as Map<String, dynamic>;

    final firstComparison = (aProperties['first_airport_id'] as int).compareTo(
      bProperties['first_airport_id'] as int,
    );

    if (firstComparison != 0) {
      return firstComparison;
    }

    return (aProperties['second_airport_id'] as int).compareTo(
      bProperties['second_airport_id'] as int,
    );
  });

  return jsonEncode({'type': 'FeatureCollection', 'features': features});
}

/// Whether all generated points represent the same geographic position.
///
/// Longitude differences of 360 degrees represent the same meridian.
/// This also handles +180 and -180 as equivalent coordinates.
bool _hasNoGeographicExtent(List<FlightRoutePoint> points) {
  final first = points.first;

  const tolerance = 1e-10;

  for (final point in points.skip(1)) {
    if ((point.latitude - first.latitude).abs() > tolerance) {
      return false;
    }

    final difference = (point.longitude - first.longitude).abs();

    final wrappedDifference = difference > 180 ? 360 - difference : difference;

    if (wrappedDifference.abs() > tolerance) {
      return false;
    }
  }

  return true;
}

/// Splits great-circle points whenever consecutive longitudes
/// cross the antimeridian.
///
/// Each returned line contains at least two points.
///
/// Coordinates follow the GeoJSON [longitude, latitude] convention.
///
/// A crossing is represented by two boundary points:
///
/// - The current line terminates at +180 or -180.
/// - The next line starts at the opposite representation.
///
/// This prevents a renderer from joining +179 to -179
/// across the entire world map.
List<List<List<double>>> _splitAtAntimeridian(List<FlightRoutePoint> points) {
  if (points.length < 2) {
    return const [];
  }

  final lines = <List<List<double>>>[];

  var currentLine = <List<double>>[
    [points.first.longitude, points.first.latitude],
  ];

  for (var index = 1; index < points.length; index++) {
    final previous = points[index - 1];
    final current = points[index];

    final previousLongitude = previous.longitude;
    final currentLongitude = current.longitude;

    final longitudeDifference = currentLongitude - previousLongitude;

    // -----------------------------------------------------------------------
    // Normal segment: no antimeridian crossing.
    // -----------------------------------------------------------------------

    if (longitudeDifference.abs() <= 180) {
      currentLine.add([currentLongitude, current.latitude]);

      continue;
    }

    // -----------------------------------------------------------------------
    // Determine the crossing direction.
    //
    // +179 -> -179 crosses eastward at +180.
    // -179 -> +179 crosses westward at -180.
    // -----------------------------------------------------------------------

    final crossesEastward = longitudeDifference < -180;

    final boundaryLongitude = crossesEastward ? 180.0 : -180.0;

    final oppositeBoundaryLongitude = -boundaryLongitude;

    // Unwrap the next longitude so the segment is continuous.
    final unwrappedCurrentLongitude = crossesEastward
        ? currentLongitude + 360
        : currentLongitude - 360;

    final denominator = unwrappedCurrentLongitude - previousLongitude;

    if (denominator == 0) {
      // Defensive fallback. A genuine crossing should
      // always have a nonzero unwrapped longitude difference.
      currentLine.add([currentLongitude, current.latitude]);

      continue;
    }

    // -----------------------------------------------------------------------
    // Interpolate the boundary latitude.
    //
    // The great-circle geometry is already densely sampled.
    // Linear interpolation is applied only within the small
    // segment that crosses the longitude boundary.
    // -----------------------------------------------------------------------

    final fraction = (boundaryLongitude - previousLongitude) / denominator;

    final crossingLatitude =
        previous.latitude + fraction * (current.latitude - previous.latitude);

    // End the current line at the boundary.
    currentLine.add([boundaryLongitude, crossingLatitude]);

    if (currentLine.length >= 2) {
      lines.add(currentLine);
    }

    // Start a new line at the opposite representation
    // of the same geographic boundary.
    currentLine = [
      [oppositeBoundaryLongitude, crossingLatitude],
      [currentLongitude, current.latitude],
    ];
  }

  if (currentLine.length >= 2) {
    lines.add(currentLine);
  }

  return lines;
}
