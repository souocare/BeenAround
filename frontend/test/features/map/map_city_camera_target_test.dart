import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_city_camera_target.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';

void main() {
  group('calculateMapCityCameraCenter', () {
    test('uses the city geographic coordinates', () {
      const city = MapCityData(
        cityId: 123,
        name: 'Madrid',
        countryCode: 'ES',
        countryName: 'Spain',
        latitude: 40.4168,
        longitude: -3.7038,
        visitCount: 1,
        residenceCount: 0,
        isWishlisted: false,
      );

      final center = calculateMapCityCameraCenter(city);

      expect(center.lat, closeTo(40.4168, 0.000001));
      expect(center.lon, closeTo(-3.7038, 0.000001));
    });
  });
}
