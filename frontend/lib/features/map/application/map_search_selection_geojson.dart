import 'dart:convert';

import '../domain/map_search_destination.dart';

/// Builds the GeoJSON representation of a temporary geographic
/// destination selected through catalog search.
///
/// Country selections use the existing country geometry and
/// therefore do not produce a Point feature.
///
/// City and airport selections produce at most one Point.
///
/// The resulting GeoJSON is independent of MapLibre and
/// never modifies personal travel records.
String buildMapSearchSelectionGeoJson({
  required MapSearchDestination? destination,
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
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [destination.longitude, destination.latitude],
      },
    });
  }

  return jsonEncode({'type': 'FeatureCollection', 'features': features});
}
