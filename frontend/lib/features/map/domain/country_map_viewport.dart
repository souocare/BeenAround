import 'dart:math' as math;

import 'country_geometry_bounds.dart';

class CountryMapViewport {
  const CountryMapViewport({
    required this.longitude,
    required this.latitude,
    required this.zoom,
  });

  final double longitude;
  final double latitude;
  final double zoom;
}

CountryMapViewport calculateCountryMapViewport({
  required CountryGeometryBounds bounds,
  required double width,
  required double height,
}) {
  const tileSize = 512.0;
  const paddingFactor = 0.95;

  final availableWidth = math.max(1.0, width * paddingFactor);
  final availableHeight = math.max(1.0, height * paddingFactor);

  double latitudeToMercatorY(double latitude) {
    final clamped = latitude.clamp(-85.05112878, 85.05112878);
    final radians = clamped * math.pi / 180;

    final mercator = math.log(math.tan(math.pi / 4 + radians / 2));

    return (1 - mercator / math.pi) / 2;
  }

  double mercatorYToLatitude(double y) {
    final mercator = math.pi * (1 - 2 * y);

    return (2 * math.atan(math.exp(mercator)) - math.pi / 2) * 180 / math.pi;
  }

  final westX = (bounds.west + 180) / 360;
  final eastX = (bounds.east + 180) / 360;

  final northY = latitudeToMercatorY(bounds.north);
  final southY = latitudeToMercatorY(bounds.south);

  final longitudeSpan = math.max((eastX - westX).abs(), 1e-9);
  final latitudeSpan = math.max((southY - northY).abs(), 1e-9);

  final zoomX =
      math.log(availableWidth / (tileSize * longitudeSpan)) / math.ln2;

  final zoomY =
      math.log(availableHeight / (tileSize * latitudeSpan)) / math.ln2;

  final zoom = math.min(zoomX, zoomY).clamp(1.0, 14.0).toDouble();

  final centerY = (northY + southY) / 2;

  return CountryMapViewport(
    longitude: (bounds.west + bounds.east) / 2,
    latitude: mercatorYToLatitude(centerY),
    zoom: zoom,
  );
}
