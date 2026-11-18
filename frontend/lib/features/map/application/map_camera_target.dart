import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';

/// Camera destination calculated independently of MapLibre rendering.
class MapCameraTarget {
  const MapCameraTarget({required this.center, required this.zoom});

  final Geographic center;
  final double zoom;
}

/// Calculates a contextual camera position using Web Mercator.
///
/// The country is fitted within the available viewport, accounting for
/// padding and limiting zoom to preserve surrounding geographic context.
///
/// Assumes an unrotated, unpitched map and conventional bounds that do
/// not cross the antimeridian.
MapCameraTarget calculateMapCameraTarget({
  required LngLatBounds bounds,
  required Size viewportSize,
  EdgeInsets padding = EdgeInsets.zero,
  double minZoom = 1.0,
  double maxZoom = 5.5,
}) {
  if (viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      !viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      minZoom > maxZoom ||
      !minZoom.isFinite ||
      !maxZoom.isFinite) {
    throw ArgumentError('Invalid map camera dimensions or zoom limits.');
  }

  final availableWidth = viewportSize.width - padding.horizontal;
  final availableHeight = viewportSize.height - padding.vertical;

  if (availableWidth <= 0 || availableHeight <= 0) {
    throw ArgumentError('Map camera padding exceeds viewport dimensions.');
  }

  final west = _longitudeToX(bounds.longitudeWest);
  final east = _longitudeToX(bounds.longitudeEast);

  final north = _latitudeToY(bounds.latitudeNorth);
  final south = _latitudeToY(bounds.latitudeSouth);

  final width = (east - west).abs();
  final height = (south - north).abs();

  if (width == 0 && height == 0) {
    throw ArgumentError('Country bounds have no geographic extent.');
  }

  // Web Mercator world width at zoom zero is 512 logical pixels.
  const tileSize = 512.0;

  final horizontalZoom = width == 0
      ? maxZoom
      : math.log(availableWidth / (tileSize * width)) / math.ln2;

  final verticalZoom = height == 0
      ? maxZoom
      : math.log(availableHeight / (tileSize * height)) / math.ln2;

  final zoom = math
      .min(horizontalZoom, verticalZoom)
      .clamp(minZoom, maxZoom)
      .toDouble();

  final worldPixels = tileSize * math.pow(2, zoom).toDouble();

  // The centre of the padded area may differ from the screen centre.
  // Offset the camera so the country appears centred inside that area.
  final xOffset = (padding.left - padding.right) / (2 * worldPixels);

  final yOffset = (padding.top - padding.bottom) / (2 * worldPixels);

  final centerX = (west + east) / 2 - xOffset;
  final centerY = (north + south) / 2 - yOffset;

  return MapCameraTarget(
    center: Geographic(
      lon: _xToLongitude(centerX),
      lat: _yToLatitude(centerY.clamp(0.0, 1.0).toDouble()),
    ),
    zoom: zoom,
  );
}

double _longitudeToX(double longitude) {
  return (longitude + 180) / 360;
}

double _latitudeToY(double latitude) {
  final clamped = latitude.clamp(-85.051129, 85.051129).toDouble();
  final radians = clamped * math.pi / 180;

  final tangent = math.tan(radians);

  // asinh(x) = ln(x + sqrt(x² + 1))
  final inverseHyperbolicSine = math.log(
    tangent + math.sqrt(tangent * tangent + 1),
  );

  return (1 - inverseHyperbolicSine / math.pi) / 2;
}

double _xToLongitude(double x) {
  final longitude = x * 360 - 180;
  return ((longitude + 180) % 360 + 360) % 360 - 180;
}

double _yToLatitude(double y) {
  final value = math.pi * (1 - 2 * y);

  // sinh(x) = (e^x - e^-x) / 2
  final hyperbolicSine = (math.exp(value) - math.exp(-value)) / 2;

  return math.atan(hyperbolicSine) * 180 / math.pi;
}
