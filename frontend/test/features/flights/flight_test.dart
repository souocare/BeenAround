import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validFlightJson() {
    return {
      'id': 'eab8a20b-f1c7-4e35-a0a7-15596e144a93',
      'departure_airport_id': 100,
      'arrival_airport_id': 200,
      'airline_id': 10,
      'airline_name': null,
      'flight_number': 'TP1920',
      'departure_on': '2025-09-10',
      'departure_time': '22:30:00',
      'arrival_on': '2025-09-11',
      'arrival_time': '00:45:00',
      'status': 'flown',
      'aircraft_type': 'Airbus A320',
      'aircraft_registration': 'CS-TVA',
      'seat': '12A',
      'cabin_class': 'economy',
      'notes': 'First flight',
      'created_at': '2026-11-11T17:00:00',
      'updated_at': '2026-11-11T17:00:00',
    };
  }

  test('parses a complete flight', () {
    final flight = Flight.fromJson(validFlightJson());

    expect(flight.departureAirportId, 100);
    expect(flight.arrivalAirportId, 200);
    expect(flight.airlineId, 10);
    expect(flight.flightNumber, 'TP1920');
    expect(flight.status, FlightStatus.flown);
    expect(flight.cabinClass, FlightCabinClass.economy);
    expect(flight.isFlown, isTrue);
    expect(flight.isPlanned, isFalse);
  });

  test('preserves local dates and times', () {
    final json = validFlightJson()
      ..['departure_on'] = '2025-09-11'
      ..['departure_time'] = '23:30:00'
      ..['arrival_on'] = '2025-09-10'
      ..['arrival_time'] = '18:45:00';

    final flight = Flight.fromJson(json);

    expect(flight.departureOn, '2025-09-11');
    expect(flight.departureTime, '23:30:00');
    expect(flight.arrivalOn, '2025-09-10');
    expect(flight.arrivalTime, '18:45:00');
  });

  test('parses a minimal flight', () {
    final json = validFlightJson()
      ..['airline_id'] = null
      ..['flight_number'] = null
      ..['departure_time'] = null
      ..['arrival_on'] = null
      ..['arrival_time'] = null
      ..['aircraft_type'] = null
      ..['aircraft_registration'] = null
      ..['seat'] = null
      ..['cabin_class'] = null
      ..['notes'] = null;

    final flight = Flight.fromJson(json);

    expect(flight.airlineId, isNull);
    expect(flight.departureTime, isNull);
    expect(flight.cabinClass, isNull);
  });

  test('parses planned flights', () {
    final json = validFlightJson()..['status'] = 'planned';

    final flight = Flight.fromJson(json);

    expect(flight.isPlanned, isTrue);
    expect(flight.isFlown, isFalse);
  });

  test('rejects an unsupported status', () {
    final json = validFlightJson()..['status'] = 'cancelled';

    expect(() => Flight.fromJson(json), throwsFormatException);
  });

  test('rejects an unsupported cabin class', () {
    final json = validFlightJson()..['cabin_class'] = 'private';

    expect(() => Flight.fromJson(json), throwsFormatException);
  });

  test('parses pagination metadata', () {
    final page = FlightPage.fromJson({
      'items': [validFlightJson()],
      'total': 25,
      'limit': 20,
      'offset': 0,
    });

    expect(page.items, hasLength(1));
    expect(page.total, 25);
    expect(page.hasMore, isTrue);
  });

  test('identifies the final page', () {
    final page = FlightPage.fromJson({
      'items': [validFlightJson()],
      'total': 21,
      'limit': 20,
      'offset': 20,
    });

    expect(page.hasMore, isFalse);
  });

  test('rejects an invalid list response', () {
    expect(
      () => FlightPage.fromJson({
        'items': 'invalid',
        'total': 0,
        'limit': 20,
        'offset': 0,
      }),
      throwsFormatException,
    );
  });
}
