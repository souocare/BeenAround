import 'package:flutter/services.dart';

class WorldGeoJsonRepository {
  WorldGeoJsonRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/geo/world_countries.geojson',
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  /// Geographic asset loaded by this repository.
  ///
  /// The default preserves compatibility with existing consumers.
  final String assetPath;

  Future<String>? _cachedGeoJson;

  Future<String> load() {
    return _cachedGeoJson ??= _load();
  }

  Future<String> _load() async {
    try {
      return await _assetBundle.loadString(assetPath);
    } catch (_) {
      _cachedGeoJson = null;
      rethrow;
    }
  }
}
