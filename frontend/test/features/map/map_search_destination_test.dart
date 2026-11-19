import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_search_destination.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/flights/domain/airport.dart';

void main() {
  group('MapSearchDestination', () {
    test('creates a country destination with normalized identity', () {
      final destination = MapSearchDestination.country(
        code: ' pt ',
        name: 'Portugal',
      );

      expect(destination.type, MapSearchDestinationType.country);
      expect(destination.id, 'country:PT');
      expect(destination.title, 'Portugal');
      expect(destination.countryCode, 'PT');
      expect(destination.hasCoordinates, isFalse);
    });

    test('creates a city destination with catalog coordinates', () {
      const city = City(
        id: 123,
        countryCode: 'ES',
        countryName: 'Spain',
        name: 'Madrid',
        asciiName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
        population: 3200000,
        featureCode: 'PPLC',
      );

      final destination = MapSearchDestination.city(city);

      expect(destination.type, MapSearchDestinationType.city);
      expect(destination.id, 'city:123');
      expect(destination.title, 'Madrid');
      expect(destination.subtitle, 'Spain');
      expect(destination.hasCoordinates, isTrue);
      expect(destination.latitude, 40.4168);
      expect(destination.longitude, -3.7038);
    });

    test('creates an airport destination with aviation identity', () {
      const airport = Airport(
        id: 456,
        ident: 'LPPT',
        name: 'Humberto Delgado Airport',
        type: 'large_airport',
        scheduledService: true,
        iataCode: 'LIS',
        icaoCode: 'LPPT',
        municipality: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        latitude: 38.7742,
        longitude: -9.1342,
      );

      final destination = MapSearchDestination.airport(airport);

      expect(destination.type, MapSearchDestinationType.airport);
      expect(destination.id, 'airport:456');
      expect(destination.title, 'Humberto Delgado Airport');
      expect(destination.subtitle, contains('LIS'));
      expect(destination.hasCoordinates, isTrue);
    });

    test('supports airports without coordinates', () {
      const airport = Airport(
        id: 789,
        ident: 'TEST',
        name: 'Test Airport',
        type: 'small_airport',
        scheduledService: false,
      );

      final destination = MapSearchDestination.airport(airport);

      expect(destination.id, 'airport:789');
      expect(destination.hasCoordinates, isFalse);
    });

    test('rejects invalid geographic coordinates', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:999',
        title: 'Invalid location',
        subtitle: 'Test',
        latitude: 120,
        longitude: 200,
      );

      expect(destination.hasCoordinates, isFalse);
    });

    test('keeps city and airport catalog identities separate', () {
      const city = City(
        id: 123,
        countryCode: 'PT',
        countryName: 'Portugal',
        name: 'Lisbon',
        asciiName: 'Lisbon',
        latitude: 38.72,
        longitude: -9.14,
        population: 500000,
        featureCode: 'PPLC',
      );

      const airport = Airport(
        id: 123,
        ident: 'LPPT',
        name: 'Lisbon Airport',
        type: 'large_airport',
        scheduledService: true,
      );

      final cityDestination = MapSearchDestination.city(city);
      final airportDestination = MapSearchDestination.airport(airport);

      expect(cityDestination.id, isNot(airportDestination.id));
    });
  });
}
