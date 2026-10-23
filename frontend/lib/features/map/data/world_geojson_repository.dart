import 'package:flutter/services.dart';

class WorldGeoJsonRepository {
  WorldGeoJsonRepository({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  Future<String>? _cachedGeoJson;

  Future<String> load() {
    return _cachedGeoJson ??= _load();
  }

  Future<String> _load() async {
    try {
      return await _assetBundle.loadString(
        'assets/geo/world_countries.geojson',
      );
    } catch (_) {
      _cachedGeoJson = null;
      rethrow;
    }
  }
}
