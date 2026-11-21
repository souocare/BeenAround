import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_selected_flight_route_geojson.dart';

void main() {
  final routesGeoJson = jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {'route_id': '1:2'},
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [-9.13, 38.77],
              [-3.57, 40.49],
            ],
          ],
        },
      },
      {
        'type': 'Feature',
        'properties': {'route_id': '1:3'},
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [-9.13, 38.77],
              [-0.45, 51.47],
            ],
          ],
        },
      },
    ],
  });

  List<dynamic> features(String geoJson) {
    return (jsonDecode(geoJson) as Map<String, dynamic>)['features']
        as List<dynamic>;
  }

  test('returns an empty collection without selection', () {
    final result = buildMapSelectedFlightRouteGeoJson(
      flightRoutesGeoJson: routesGeoJson,
      selectedRouteId: null,
    );

    expect(features(result), isEmpty);
  });

  test('extracts only the selected connection', () {
    final result = buildMapSelectedFlightRouteGeoJson(
      flightRoutesGeoJson: routesGeoJson,
      selectedRouteId: '1:3',
    );

    final selected = features(result);

    expect(selected, hasLength(1));

    final properties =
        (selected.single as Map<String, dynamic>)['properties']
            as Map<String, dynamic>;

    expect(properties['route_id'], '1:3');
  });

  test('returns an empty collection for an unknown route', () {
    final result = buildMapSelectedFlightRouteGeoJson(
      flightRoutesGeoJson: routesGeoJson,
      selectedRouteId: '99:100',
    );

    expect(features(result), isEmpty);
  });

  test('preserves the original route geometry', () {
    final result = buildMapSelectedFlightRouteGeoJson(
      flightRoutesGeoJson: routesGeoJson,
      selectedRouteId: '1:2',
    );

    final selectedGeometry =
        (features(result).single as Map<String, dynamic>)['geometry'];

    final originalGeometry =
        ((jsonDecode(routesGeoJson) as Map<String, dynamic>)['features']
                as List<dynamic>)
            .first['geometry'];

    expect(selectedGeometry, originalGeometry);
  });
}
