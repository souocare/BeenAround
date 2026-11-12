import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> airlineJson() => {
    'id': 10,
    'name': 'TAP Air Portugal',
    'iata_code': 'TP',
    'icao_code': 'TAP',
    'callsign': 'AIR PORTUGAL',
    'country_name': 'Portugal',
  };

  test('parses airline catalog response', () {
    final airline = Airline.fromJson(airlineJson());

    expect(airline.id, 10);
    expect(airline.name, 'TAP Air Portugal');
    expect(airline.displayCode, 'TP');
    expect(airline.displayName, 'TP · TAP Air Portugal');
  });

  test('supports airlines without IATA codes', () {
    final json = airlineJson()..['iata_code'] = null;

    expect(Airline.fromJson(json).displayCode, 'TAP');
  });

  test('supports airlines without aviation codes', () {
    final json = airlineJson()
      ..['iata_code'] = null
      ..['icao_code'] = null;

    final airline = Airline.fromJson(json);

    expect(airline.displayCode, isNull);
    expect(airline.displayName, 'TAP Air Portugal');
  });

  test('parses airline pagination', () {
    final page = AirlinePage.fromJson({
      'items': [airlineJson()],
      'total': 86,
      'limit': 20,
      'offset': 0,
    });

    expect(page.items, hasLength(1));
    expect(page.total, 86);
    expect(page.hasMore, isTrue);
  });

  test('rejects malformed airline results', () {
    expect(
      () => AirlinePage.fromJson({
        'items': 'invalid',
        'total': 0,
        'limit': 20,
        'offset': 0,
      }),
      throwsFormatException,
    );
  });
}
