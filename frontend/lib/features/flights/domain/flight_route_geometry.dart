import 'dart:math' as math;

import 'airport.dart';

/// Geographic coordinate of a flight route.
///
/// Longitude and latitude are expressed in degrees.
class FlightRoutePoint {
  const FlightRoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Generates a great-circle route between two airports.
///
/// The route represents the shortest path over a spherical Earth,
/// not necessarily the actual trajectory flown by the aircraft.
///
/// Does not depend on Flutter, MapLibre or external services.
class FlightRouteGeometry {
  const FlightRouteGeometry._();

  static const int defaultSegments = 64;

  static List<FlightRoutePoint> between(
    Airport departure,
    Airport arrival, {
    int segments = defaultSegments,
  }) {
    if (segments < 1) {
      throw ArgumentError.value(segments, 'segments', 'Must be at least 1.');
    }

    final lat1 = departure.latitude;
    final lon1 = departure.longitude;

    final lat2 = arrival.latitude;
    final lon2 = arrival.longitude;

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return const [];
    }

    if (!_valid(lat1, lon1) || !_valid(lat2, lon2)) {
      return const [];
    }

    final start = _toCartesian(lat1, lon1);
    final end = _toCartesian(lat2, lon2);

    final dot = _clamp(
      start.$1 * end.$1 + start.$2 * end.$2 + start.$3 * end.$3,
      -1,
      1,
    );

    final omega = math.acos(dot);
    final sinOmega = math.sin(omega);

    // Coincident or nearly antipodal points do not have
    // a numerically stable unique interpolation.
    //
    // In those cases, avoid inventing a trajectory.
    if (omega < 1e-10 || sinOmega.abs() < 1e-10) {
      return [
        FlightRoutePoint(latitude: lat1, longitude: lon1),
        FlightRoutePoint(latitude: lat2, longitude: lon2),
      ];
    }

    return List.generate(segments + 1, (index) {
      final fraction = index / segments;

      final weightStart = math.sin((1 - fraction) * omega) / sinOmega;

      final weightEnd = math.sin(fraction * omega) / sinOmega;

      final x = weightStart * start.$1 + weightEnd * end.$1;

      final y = weightStart * start.$2 + weightEnd * end.$2;

      final z = weightStart * start.$3 + weightEnd * end.$3;

      final latitude = math.atan2(z, math.sqrt(x * x + y * y));

      final longitude = math.atan2(y, x);

      return FlightRoutePoint(
        latitude: latitude * 180 / math.pi,
        longitude: longitude * 180 / math.pi,
      );
    });
  }

  static (double, double, double) _toCartesian(
    double latitude,
    double longitude,
  ) {
    final lat = latitude * math.pi / 180;
    final lon = longitude * math.pi / 180;

    return (
      math.cos(lat) * math.cos(lon),
      math.cos(lat) * math.sin(lon),
      math.sin(lat),
    );
  }

  static double _clamp(double value, double minimum, double maximum) {
    return math.max(minimum, math.min(maximum, value));
  }

  static bool _valid(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
