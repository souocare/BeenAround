import 'dart:convert';

/// Builds a GeoJSON FeatureCollection containing only the selected countries.
///
/// The source geometry is never modified.
///
/// Country codes without a corresponding feature are safely omitted.
String buildMapCountryHighlightGeoJson({
  required String worldGeoJson,
  required Set<String> countryCodes,
}) {
  if (countryCodes.isEmpty) {
    return '{"type":"FeatureCollection","features":[]}';
  }

  final decoded = jsonDecode(worldGeoJson);

  if (decoded is! Map<String, dynamic> ||
      decoded['type'] != 'FeatureCollection') {
    throw const FormatException('Invalid world GeoJSON.');
  }

  final features = decoded['features'];

  if (features is! List) {
    throw const FormatException('Invalid world GeoJSON features.');
  }

  final highlightedFeatures = <dynamic>[];

  for (final feature in features) {
    if (feature is! Map) {
      throw const FormatException('Invalid world GeoJSON feature.');
    }

    final properties = feature['properties'];

    if (properties is! Map) {
      throw const FormatException('Invalid country properties.');
    }

    final countryCode = properties['country_code'];

    if (countryCode is String && countryCodes.contains(countryCode)) {
      highlightedFeatures.add(feature);
    }
  }

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': highlightedFeatures,
  });
}
