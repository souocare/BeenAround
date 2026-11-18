import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/map/data/country_geometry_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Spain geometry is available in the Flutter asset bundle', () async {
    final repository = CountryGeometryRepository();

    final geoJson = await repository.load('ES');

    final decoded = jsonDecode(geoJson);

    expect(decoded, isA<Map<String, dynamic>>());
    expect(geoJson, contains('"coordinates"'));
  });
}
