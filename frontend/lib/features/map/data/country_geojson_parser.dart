import 'dart:convert';

import 'world_country_loader.dart';

class CountryGeoJsonParser {
  const CountryGeoJsonParser();

  WorldCountryGeometry parse(String source) {
    final collection = jsonDecode(source) as Map<String, dynamic>;

    if (collection['type'] != 'FeatureCollection') {
      throw const FormatException('Expected GeoJSON FeatureCollection.');
    }

    final features = collection['features'] as List<dynamic>;

    if (features.length != 1) {
      throw const FormatException('Expected exactly one country feature.');
    }

    final feature = features.single as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    final code = properties['country_code'] as String?;
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    List<List<List<double>>> parsePolygon(dynamic rawPolygon) {
      return (rawPolygon as List<dynamic>).map((rawRing) {
        return (rawRing as List<dynamic>).map((rawPosition) {
          final position = rawPosition as List<dynamic>;

          return [
            (position[0] as num).toDouble(),
            (position[1] as num).toDouble(),
          ];
        }).toList();
      }).toList();
    }

    final polygons = switch (type) {
      'Polygon' => [parsePolygon(coordinates)],
      'MultiPolygon' => coordinates.map(parsePolygon).toList(),
      _ => throw FormatException('Unsupported geometry: $type'),
    };

    return WorldCountryGeometry(countryCode: code, polygons: polygons);
  }
}
