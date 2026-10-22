import 'dart:convert';

import 'package:flutter/services.dart';

class WorldCountryGeometry {
  const WorldCountryGeometry({
    required this.countryCode,
    required this.polygons,
  });

  final String? countryCode;

  /// Polygon -> rings -> coordinates [longitude, latitude].
  final List<List<List<List<double>>>> polygons;
}

class WorldCountryLoader {
  const WorldCountryLoader();

  Future<List<WorldCountryGeometry>> load() async {
    final source = await rootBundle.loadString(
      'assets/geo/world_countries.geojson',
    );

    final collection = jsonDecode(source) as Map<String, dynamic>;
    final features = collection['features'] as List<dynamic>;

    return features
        .map((rawFeature) {
          final feature = rawFeature as Map<String, dynamic>;
          final properties = feature['properties'] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;

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

          return WorldCountryGeometry(
            countryCode: properties['country_code'] as String?,
            polygons: polygons,
          );
        })
        .toList(growable: false);
  }
}
