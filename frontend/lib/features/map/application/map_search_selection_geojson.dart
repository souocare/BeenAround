import 'dart:convert';

import '../domain/map_search_destination.dart';

/// Builds the GeoJSON representation of a selected geographic
/// catalog destination.
///
/// Country selections use the existing country geometry and
/// therefore do not produce a Point feature.
///
/// City and airport selections produce at most one Point.
///
/// Airport usage controls presentation only. It does not
/// modify personal flight or geographic records.
///
/// The resulting GeoJSON is independent of MapLibre.
String buildMapSearchSelectionGeoJson({
  required MapSearchDestination? destination,
  bool isUsedAirport = false,
}) {
  final features = <Map<String, Object?>>[];

  if (destination != null &&
      destination.type != MapSearchDestinationType.country &&
      destination.hasCoordinates) {
    features.add({
      'type': 'Feature',
      'id': destination.id,
      'properties': {
        'destination_id': destination.id,
        'destination_type': destination.type.name,
        'name': destination.title,
        'country_code': destination.countryCode,

        // Presentation metadata for airport selection styling.
        'is_used_airport':
            destination.type == MapSearchDestinationType.airport &&
            isUsedAirport,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [destination.longitude, destination.latitude],
      },
    });
  }

  return jsonEncode({'type': 'FeatureCollection', 'features': features});
}
