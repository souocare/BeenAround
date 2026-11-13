import 'dart:math' as math;

import 'airport.dart';

/// Calculates the shortest surface distance between two airports.
///
/// This is a great-circle distance, not the actual flown distance.
///
/// Returns null when either airport has no valid coordinates.
class FlightDistance {
  const FlightDistance._();

  static const double _earthRadiusKm = 6371.0088;

  static double? between(Airport? departure, Airport? arrival) {
    if (departure == null || arrival == null) {
      return null;
    }

    final lat1 = departure.latitude;
    final lon1 = departure.longitude;
    final lat2 = arrival.latitude;
    final lon2 = arrival.longitude;

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }

    if (!_validCoordinates(lat1, lon1) || !_validCoordinates(lat2, lon2)) {
      return null;
    }

    final latitudeDifference = _radians(lat2 - lat1);
    final longitudeDifference = _radians(lon2 - lon1);

    final a =
        math.pow(math.sin(latitudeDifference / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(longitudeDifference / 2), 2);

    final clampedA = a.clamp(0.0, 1.0);

    final angularDistance =
        2 * math.atan2(math.sqrt(clampedA), math.sqrt(1 - clampedA));

    return _earthRadiusKm * angularDistance;
  }

  static double _radians(double degrees) {
    return degrees * math.pi / 180;
  }

  static bool _validCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
