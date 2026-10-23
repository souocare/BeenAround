import 'package:flutter/services.dart';

class CountryGeometryRepository {
  CountryGeometryRepository({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  final Map<String, Future<String>> _cache = {};

  Future<String> load(String countryCode) {
    final normalizedCode = countryCode.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCode)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Must be a valid ISO2 country code.',
      );
    }

    return _cache.putIfAbsent(
      normalizedCode,
      () => _loadCountry(normalizedCode),
    );
  }

  Future<String> _loadCountry(String countryCode) async {
    try {
      final data = await _assetBundle.load(
        'assets/geo/countries/$countryCode.geojson',
      );

      return String.fromCharCodes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      _cache.remove(countryCode);
      rethrow;
    }
  }
}
