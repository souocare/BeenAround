import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> airportJson() => {
    'id': 100,
    'ident': 'LPPT',
    'iata_code': 'LIS',
    'icao_code': 'LPPT',
    'name': 'Lisbon Humberto Delgado Airport',
    'municipality': 'Lisbon',
    'source_country_code': 'PT',
    'country_code': 'PT',
    'country_name': 'Portugal',
    'latitude': 38.77,
    'longitude': -9.13,
    'type': 'large_airport',
    'scheduled_service': true,
  };

  test('parses airport catalog response', () {
    final airport = Airport.fromJson(airportJson());

    expect(airport.id, 100);
    expect(airport.displayCode, 'LIS');
    expect(airport.displayLocation, 'Lisbon, Portugal');
    expect(airport.hasCoordinates, isTrue);
    expect(airport.scheduledService, isTrue);
  });

  test('uses ICAO when IATA is unavailable', () {
    final json = airportJson()..['iata_code'] = null;

    final airport = Airport.fromJson(json);

    expect(airport.displayCode, 'LPPT');
  });

  test('uses ident when both aviation codes are unavailable', () {
    final json = airportJson()
      ..['iata_code'] = null
      ..['icao_code'] = null;

    expect(Airport.fromJson(json).displayCode, 'LPPT');
  });

  test('supports airports without coordinates', () {
    final json = airportJson()
      ..['latitude'] = null
      ..['longitude'] = null;

    expect(Airport.fromJson(json).hasCoordinates, isFalse);
  });

  test('parses airport pagination', () {
    final page = AirportPage.fromJson({
      'items': [airportJson()],
      'total': 42,
      'limit': 20,
      'offset': 0,
    });

    expect(page.items, hasLength(1));
    expect(page.total, 42);
    expect(page.hasMore, isTrue);
  });

  test('rejects malformed airport pagination', () {
    expect(
      () => AirportPage.fromJson({
        'items': [],
        'total': 'invalid',
        'limit': 20,
        'offset': 0,
      }),
      throwsFormatException,
    );
  });
}
