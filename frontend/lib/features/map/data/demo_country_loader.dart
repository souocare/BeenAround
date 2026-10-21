import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:maplibre/maplibre.dart';

/// Geographic data used exclusively by the MapLibre feasibility experiment.
class DemoCountryData {
  const DemoCountryData({required this.polygons, required this.borders});

  final List<Feature<Polygon>> polygons;
  final List<Feature<LineString>> borders;
}

/// Loads local Natural Earth 10m country geometries.
///
/// The GeoJSON contains MultiPolygon geometries. Each polygon is converted
/// into a fill feature, while its rings are converted into line features.
///
/// Keeping fills and borders separate allows independent styling.
class DemoCountryLoader {
  const DemoCountryLoader();

  Future<DemoCountryData> load() async {
    final source = await rootBundle.loadString(
      'assets/geo/demo_countries.geojson',
    );

    final collection = jsonDecode(source) as Map<String, dynamic>;
    final features = collection['features'] as List<dynamic>;

    final polygons = <Feature<Polygon>>[];
    final borders = <Feature<LineString>>[];

    for (final rawFeature in features) {
      final feature = rawFeature as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      final countryCode = properties['ADM0_A3'] as String;
      final countryName = properties['ADMIN'] as String;

      if (geometry['type'] != 'MultiPolygon') {
        throw FormatException('Expected MultiPolygon for $countryCode');
      }

      final coordinates = geometry['coordinates'] as List<dynamic>;

      for (
        var polygonIndex = 0;
        polygonIndex < coordinates.length;
        polygonIndex++
      ) {
        final rawPolygon = coordinates[polygonIndex] as List<dynamic>;

        final rings = rawPolygon.map((rawRing) {
          final positions = rawRing as List<dynamic>;

          return positions.map((rawPosition) {
            final position = rawPosition as List<dynamic>;

            return [
              (position[0] as num).toDouble(),
              (position[1] as num).toDouble(),
            ];
          }).toList();
        }).toList();

        final polygonId = '$countryCode-$polygonIndex';

        // Country fill.
        polygons.add(
          Feature<Polygon>(
            id: polygonId,
            geometry: Polygon.from(
              rings.map((ring) => ring.map((position) => position.xy)),
            ),
            properties: {
              'country_code': countryCode,
              'country_name': countryName,
            },
          ),
        );

        // Country boundaries.
        //
        // Include all rings so that exterior boundaries and any holes
        // remain represented correctly.
        for (var ringIndex = 0; ringIndex < rings.length; ringIndex++) {
          final ring = rings[ringIndex];

          if (ring.length < 2) {
            continue;
          }

          borders.add(
            Feature<LineString>(
              id: '$polygonId-border-$ringIndex',
              geometry: LineString(
                ring
                    .expand((position) => position)
                    .toList()
                    .positions(Coords.xy),
              ),
              properties: {
                'country_code': countryCode,
                'country_name': countryName,
              },
            ),
          );
        }
      }
    }

    return DemoCountryData(polygons: polygons, borders: borders);
  }
}
