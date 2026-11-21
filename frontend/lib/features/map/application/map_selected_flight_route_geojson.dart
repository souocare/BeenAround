import 'dart:convert';

import 'map_state.dart' show emptyFlightRoutesGeoJson;

/// Extracts the selected connection from the existing route GeoJSON.
///
/// No geographic calculations or repository requests are performed.
String buildMapSelectedFlightRouteGeoJson({
  required String flightRoutesGeoJson,
  required String? selectedRouteId,
}) {
  if (selectedRouteId == null || selectedRouteId.isEmpty) {
    return emptyFlightRoutesGeoJson;
  }

  final collection = jsonDecode(flightRoutesGeoJson) as Map<String, dynamic>;

  final features = collection['features'] as List<dynamic>;

  final selectedFeatures = features.where((rawFeature) {
    final feature = rawFeature as Map<String, dynamic>;

    final properties = feature['properties'] as Map<String, dynamic>;

    return properties['route_id'] == selectedRouteId;
  }).toList();

  if (selectedFeatures.isEmpty) {
    return emptyFlightRoutesGeoJson;
  }

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': selectedFeatures,
  });
}
