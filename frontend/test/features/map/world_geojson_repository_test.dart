import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/data/world_geojson_repository.dart';

class FakeWorldAssetBundle extends AssetBundle {
  FakeWorldAssetBundle(this.source);

  final String source;

  int loadCount = 0;
  bool shouldFail = false;
  String? lastLoadedKey;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    lastLoadedKey = key;

    if (shouldFail) {
      throw FlutterError('Asset unavailable');
    }

    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

void main() {
  const geoJson = '''
  {
    "type": "FeatureCollection",
    "features": []
  }
  ''';

  test('loads the default world GeoJSON asset', () async {
    final bundle = FakeWorldAssetBundle(geoJson);

    final repository = WorldGeoJsonRepository(assetBundle: bundle);

    final result = await repository.load();

    expect(result, geoJson);
    expect(bundle.loadCount, 1);

    expect(bundle.lastLoadedKey, 'assets/geo/world_countries.geojson');
  });

  test('caches successful loads', () async {
    final bundle = FakeWorldAssetBundle(geoJson);

    final repository = WorldGeoJsonRepository(assetBundle: bundle);

    await repository.load();
    await repository.load();

    expect(bundle.loadCount, 1);
  });

  test('retries after a loading failure', () async {
    final bundle = FakeWorldAssetBundle(geoJson)..shouldFail = true;

    final repository = WorldGeoJsonRepository(assetBundle: bundle);

    await expectLater(repository.load(), throwsFlutterError);

    bundle.shouldFail = false;

    expect(await repository.load(), geoJson);
    expect(bundle.loadCount, 2);
  });
  test('loads a custom world GeoJSON asset', () async {
    final bundle = FakeWorldAssetBundle(geoJson);

    final repository = WorldGeoJsonRepository(
      assetBundle: bundle,
      assetPath: 'assets/geo/world_countries_complete.geojson',
    );

    final result = await repository.load();

    expect(result, geoJson);
    expect(bundle.loadCount, 1);

    expect(bundle.lastLoadedKey, 'assets/geo/world_countries_complete.geojson');
  });
  test('caches custom asset loads', () async {
    final bundle = FakeWorldAssetBundle(geoJson);

    final repository = WorldGeoJsonRepository(
      assetBundle: bundle,
      assetPath: 'assets/geo/world_countries_complete.geojson',
    );

    final first = await repository.load();
    final second = await repository.load();

    expect(first, geoJson);
    expect(second, geoJson);
    expect(bundle.loadCount, 1);
  });
}
