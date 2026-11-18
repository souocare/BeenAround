import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_country_highlight_geojson.dart';

void main() {
  const worldGeoJson = '''
  {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "properties": {
          "country_code": "PT",
          "country_name": "Portugal"
        },
        "geometry": {
          "type": "Polygon",
          "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]
        }
      },
      {
        "type": "Feature",
        "properties": {
          "country_code": "ES",
          "country_name": "Spain"
        },
        "geometry": {
          "type": "Polygon",
          "coordinates": [[[2,0],[3,0],[3,1],[2,0]]]
        }
      },
      {
        "type": "Feature",
        "properties": {
          "country_code": null,
          "country_name": "Kosovo"
        },
        "geometry": {
          "type": "Polygon",
          "coordinates": [[[4,0],[5,0],[5,1],[4,0]]]
        }
      }
    ]
  }
  ''';

  List<dynamic> selectedFeatures(Set<String> countryCodes) {
    final result = buildMapCountryHighlightGeoJson(
      worldGeoJson: worldGeoJson,
      countryCodes: countryCodes,
    );

    return (jsonDecode(result) as Map<String, dynamic>)['features'] as List;
  }

  group('MapCountryHighlightGeoJson', () {
    test('selects only requested countries', () {
      final features = selectedFeatures({'PT'});

      expect(features.length, 1);

      expect(features.first['properties']['country_code'], 'PT');
    });

    test('supports multiple selected countries', () {
      final features = selectedFeatures({'PT', 'ES'});

      expect(features.map((feature) => feature['properties']['country_code']), [
        'PT',
        'ES',
      ]);
    });

    test('returns an empty collection for empty selection', () {
      expect(selectedFeatures({}), isEmpty);
    });

    test('ignores unknown country codes', () {
      expect(selectedFeatures({'XX'}), isEmpty);
    });

    test('does not select uncoded geographic features', () {
      final features = selectedFeatures({'PT', 'ES'});

      expect(features.length, 2);

      expect(
        features.any(
          (feature) => feature['properties']['country_code'] == null,
        ),
        isFalse,
      );
    });

    test('rejects invalid GeoJSON for nonempty selection', () {
      expect(
        () => buildMapCountryHighlightGeoJson(
          worldGeoJson: '{"type":"invalid"}',
          countryCodes: {'PT'},
        ),
        throwsFormatException,
      );
    });
  });
}
