import 'package:flutter/foundation.dart';

@immutable
class WorldMapViewport {
  const WorldMapViewport({
    required this.longitude,
    required this.latitude,
    required this.zoom,
  });

  final double longitude;
  final double latitude;
  final double zoom;
}

WorldMapViewport calculateWorldMapViewport({
  required double width,
  required double height,
}) {
  assert(width > 0);
  assert(height > 0);

  return const WorldMapViewport(longitude: 0, latitude: 0, zoom: 1.0);
}
