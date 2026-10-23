import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/data/country_geometry_repository.dart';

class FakeCountryAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets = {};

  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;

    final content = assets[key];

    if (content == null) {
      throw FlutterError('Asset not found: $key');
    }

    final bytes = Uint8List.fromList(content.codeUnits);

    return ByteData.sublistView(bytes);
  }
}

void main() {
  late FakeCountryAssetBundle assetBundle;
  late CountryGeometryRepository repository;

  setUp(() {
    assetBundle = FakeCountryAssetBundle();

    repository = CountryGeometryRepository(assetBundle: assetBundle);
  });

  test('loads the requested country asset', () async {
    assetBundle.assets['assets/geo/countries/PT.geojson'] =
        '{"type":"FeatureCollection","features":[]}';

    final result = await repository.load('PT');

    expect(result, contains('FeatureCollection'));
    expect(assetBundle.loadCount, 1);
  });

  test('normalizes ISO2 country codes', () async {
    assetBundle.assets['assets/geo/countries/PT.geojson'] = '{}';

    final result = await repository.load(' pt ');

    expect(result, '{}');
  });

  test('caches repeated requests', () async {
    assetBundle.assets['assets/geo/countries/PT.geojson'] = '{}';

    final first = repository.load('PT');
    final second = repository.load('PT');

    expect(identical(first, second), isTrue);

    await Future.wait([first, second]);

    expect(assetBundle.loadCount, 1);
  });

  test('rejects invalid country codes', () {
    expect(() => repository.load('../PT'), throwsArgumentError);

    expect(assetBundle.loadCount, 0);
  });

  test('retries after an asset loading failure', () async {
    await expectLater(repository.load('PT'), throwsFlutterError);

    assetBundle.assets['assets/geo/countries/PT.geojson'] = '{}';

    final result = await repository.load('PT');

    expect(result, '{}');
    expect(assetBundle.loadCount, 2);
  });
}
