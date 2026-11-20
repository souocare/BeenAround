import 'dart:convert';

import '../domain/map_airport_data.dart';

/// Converts personal flight airport projections into a GeoJSON
/// FeatureCollection.
///
/// Each airport is represented by a single Point feature.
///
/// GeoJSON coordinates use [longitude, latitude] order.
///
/// The resulting document is independent of MapLibre and can be
/// tested without initializing a native map renderer.
///
/// Airport presence never implies country or city visits.
String buildMapAirportGeoJson({required Iterable<MapAirportData> airports}) {
  // Deterministic ordering avoids unnecessary source updates
  // when the same airports arrive in a different order.
  final sortedAirports = airports.toList()
    ..sort((a, b) => a.airportId.compareTo(b.airportId));

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final airport in sortedAirports)
        {
          'type': 'Feature',
          'id': airport.airportId,
          'properties': {
            'airport_id': airport.airportId,
            'code': airport.code,
            'name': airport.name,
            'country_code': airport.countryCode,
            'departure_count': airport.departureCount,
            'arrival_count': airport.arrivalCount,
            'flight_count': airport.flightCount,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [airport.longitude, airport.latitude],
          },
        },
    ],
  });
}
