import 'package:maplibre/maplibre.dart';

import '../domain/map_city_data.dart';

/// Calculates the camera target for a geographic city.
///
/// City focus uses a contextual regional zoom instead of
/// attempting to frame individual streets or buildings.
Geographic calculateMapCityCameraCenter(MapCityData city) {
  return Geographic(lon: city.longitude, lat: city.latitude);
}
