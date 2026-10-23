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

  @override
  Future<ByteData> load(String key) async {
    loadCount++;

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

  test('loads the world GeoJSON asset', () async {
    final bundle = FakeWorldAssetBundle(geoJson);

    final repository = WorldGeoJsonRepository(assetBundle: bundle);

    final result = await repository.load();

    expect(result, geoJson);
    expect(bundle.loadCount, 1);
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
}
