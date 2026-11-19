import 'dart:convert';

import '../domain/map_city_data.dart';

/// Converts city map projections into a GeoJSON FeatureCollection.
///
/// Each city is represented by a single Point feature.
///
/// GeoJSON coordinates use [longitude, latitude] order.
///
/// The resulting document is independent of MapLibre and can be
/// tested without initializing a native map renderer.
String buildMapCityGeoJson({required Iterable<MapCityData> cities}) {
  // Deterministic ordering simplifies testing and avoids unnecessary
  // source updates when the same cities arrive in a different order.
  final sortedCities = cities.toList()
    ..sort((a, b) => a.cityId.compareTo(b.cityId));

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final city in sortedCities)
        {
          'type': 'Feature',
          'id': city.cityId,
          'properties': {
            'city_id': city.cityId,
            'name': city.name,
            'country_code': city.countryCode,
            'country_name': city.countryName,
            'visit_count': city.visitCount,
            'residence_count': city.residenceCount,
            'is_wishlisted': city.isWishlisted,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [city.longitude, city.latitude],
          },
        },
    ],
  });
}
