import 'dart:math' as math;

import '../../domain/flight_route_geometry.dart';

/// Camera viewport calculated for a geographic flight route.
///
/// The result is independent of MapLibre so it can be
/// tested without initializing a native map.
class FlightRouteViewport {
  const FlightRouteViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

/// Calculates a Web Mercator viewport that fits a flight route.
///
/// The route is expected to contain geographic points produced
/// by FlightRouteGeometry.
///
/// Longitudes are unwrapped to support antimeridian crossings.
class FlightRouteViewportCalculator {
  const FlightRouteViewportCalculator._();

  static const double _maximumLatitude = 85.05112878;
  static const double _tileSize = 512.0;

  static FlightRouteViewport? calculate({
    required List<FlightRoutePoint> points,
    required double width,
    required double height,
  }) {
    if (points.isEmpty ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }

    for (final point in points) {
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        return null;
      }
    }

    // Unwrap longitudes to avoid fitting the wrong side
    // of the world when crossing the antimeridian.
    final longitudes = <double>[points.first.longitude];

    for (var index = 1; index < points.length; index++) {
      var longitude = points[index].longitude;

      final previous = longitudes.last;

      while (longitude - previous > 180) {
        longitude -= 360;
      }

      while (longitude - previous < -180) {
        longitude += 360;
      }

      longitudes.add(longitude);
    }

    final xs = longitudes
        .map((longitude) => longitude / 360)
        .toList(growable: false);

    final ys = points
        .map((point) => _mercatorY(point.latitude))
        .toList(growable: false);

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);

    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final spanX = math.max(maxX - minX, 0.000001);
    final spanY = math.max(maxY - minY, 0.000001);

    // Preserve the margins already validated visually.
    final availableWidth = math.max(width - 120, 1.0);
    final availableHeight = math.max(height - 100, 1.0);

    final zoomX = _zoomForSpan(availablePixels: availableWidth, span: spanX);

    final zoomY = _zoomForSpan(availablePixels: availableHeight, span: spanY);

    final zoom = (math.min(zoomX, zoomY) - 0.85).clamp(0.5, 9.0).toDouble();

    final longitude = centerX * 360;

    // Inverse Web Mercator projection.
    //
    // Dart's math library does not provide sinh(),
    // so calculate it using the exponential definition.
    final value = math.pi * (1 - 2 * centerY);

    final sinhValue = (math.exp(value) - math.exp(-value)) / 2;

    final latitude = math.atan(sinhValue) * 180 / math.pi;

    final normalizedLongitude = ((longitude + 180) % 360 + 360) % 360 - 180;

    return FlightRouteViewport(
      latitude: latitude,
      longitude: normalizedLongitude,
      zoom: zoom,
    );
  }

  static double _mercatorY(double latitude) {
    final clamped = latitude.clamp(-_maximumLatitude, _maximumLatitude);

    final radians = clamped * math.pi / 180;

    return (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
        2;
  }

  static double _zoomForSpan({
    required double availablePixels,
    required double span,
  }) {
    return math.log(availablePixels / (_tileSize * span)) / math.ln2;
  }
}
