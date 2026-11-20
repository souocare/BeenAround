import 'dart:math' as math;

import '../domain/map_airport_data.dart';
import '../domain/map_city_data.dart';

/// Minimum visual separation between a city marker and an airport.
///
/// This represents the desired spacing between marker centers
/// in logical map pixels, not a geographic distance.
const double mapAirportMinimumSeparation = 32.0;

/// Returns airports that are sufficiently separated from visible cities.
///
/// Airport markers too close to a visible city marker are temporarily
/// suppressed to avoid visual overlap.
///
/// This function:
/// - Does not modify travel records.
/// - Does not alter airport usage statistics.
/// - Does not affect search-selected airport markers.
/// - Is independent of MapLibre's native renderer.
List<MapAirportData> calculateVisibleMapAirports({
  required Iterable<MapAirportData> airports,
  required Iterable<MapCityData> visibleCities,
  required double zoom,
  double minimumSeparation = mapAirportMinimumSeparation,
}) {
  final cities = visibleCities.toList(growable: false);

  final visibleAirports = <MapAirportData>[];

  for (final airport in airports) {
    final overlapsCity = cities.any((city) {
      final distance = calculateMapMarkerDistance(
        firstLatitude: airport.latitude,
        firstLongitude: airport.longitude,
        secondLatitude: city.latitude,
        secondLongitude: city.longitude,
        zoom: zoom,
      );

      return distance < minimumSeparation;
    });

    if (!overlapsCity) {
      visibleAirports.add(airport);
    }
  }

  return List<MapAirportData>.unmodifiable(visibleAirports);
}

/// Approximate visual distance between two geographic points
/// at a given Web Mercator zoom level.
///
/// Coordinates are projected using 512-pixel map tiles.
double calculateMapMarkerDistance({
  required double firstLatitude,
  required double firstLongitude,
  required double secondLatitude,
  required double secondLongitude,
  required double zoom,
}) {
  final worldSize = 512.0 * math.pow(2.0, zoom).toDouble();

  final firstX = _mercatorX(firstLongitude);
  final secondX = _mercatorX(secondLongitude);

  final firstY = _mercatorY(firstLatitude);
  final secondY = _mercatorY(secondLatitude);

  // Account for wrapping across the international date line.
  final rawDx = (firstX - secondX).abs();
  final dx = math.min(rawDx, 1.0 - rawDx) * worldSize;

  final dy = (firstY - secondY).abs() * worldSize;

  return math.sqrt(dx * dx + dy * dy);
}

double _mercatorX(double longitude) {
  return ((longitude + 180.0) / 360.0) % 1.0;
}

double _mercatorY(double latitude) {
  const maxLatitude = 85.05112878;

  final clampedLatitude = latitude.clamp(-maxLatitude, maxLatitude);

  final radians = clampedLatitude * math.pi / 180.0;

  return (1.0 -
          math.log(math.tan(radians) + 1.0 / math.cos(radians)) / math.pi) /
      2.0;
}
