import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/data/country_geojson_parser.dart';

void main() {
  const parser = CountryGeoJsonParser();

  test('parses a Polygon', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"country_code": "PT"},
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [-9.5, 37.0],
                [-6.0, 37.0],
                [-6.0, 42.0],
                [-9.5, 37.0]
              ]
            ]
          }
        }
      ]
    }
    ''';

    final result = parser.parse(source);

    expect(result.countryCode, 'PT');
    expect(result.polygons.length, 1);
    expect(result.polygons.first.length, 1);
  });

  test('parses a MultiPolygon', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"country_code": "PT"},
          "geometry": {
            "type": "MultiPolygon",
            "coordinates": [
              [[[-9, 38], [-8, 38], [-9, 39], [-9, 38]]],
              [[[-25, 37], [-24, 37], [-25, 38], [-25, 37]]]
            ]
          }
        }
      ]
    }
    ''';

    final result = parser.parse(source);

    expect(result.countryCode, 'PT');
    expect(result.polygons.length, 2);
  });

  test('rejects collections with multiple features', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [{}, {}]
    }
    ''';

    expect(() => parser.parse(source), throwsFormatException);
  });
}
