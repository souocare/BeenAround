import 'package:beenaround/features/flights/domain/flight_detail.dart';
import 'package:beenaround/features/flights/domain/flight_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> flightJson() {
    return {
      'id': 'e5b8e56d-e514-43c9-ae80-4c4cf064e347',
      'departure_airport_id': 100,
      'arrival_airport_id': 300,
      'airline_id': 10,
      'airline_name': null,
      'flight_number': 'TP1019',
      'departure_on': '2026-10-10',
      'departure_time': '19:20:00',
      'arrival_on': '2026-10-10',
      'arrival_time': '22:15:00',
      'status': 'flown',
      'aircraft_type': null,
      'aircraft_registration': null,
      'seat': null,
      'cabin_class': null,
      'notes': null,
      'created_at': '2026-10-10T10:00:00Z',
      'updated_at': '2026-10-10T10:00:00Z',
      'timing': {
        'departure': {'status': 'valid', 'utc_offset_minutes': 60},
        'arrival': {'status': 'valid', 'utc_offset_minutes': 120},
        'duration_minutes': 115,
      },
    };
  }

  test('parses flight and timing together', () {
    final detail = FlightDetail.fromJson(flightJson());

    expect(detail.flight.departureAirportId, 100);
    expect(detail.flight.arrivalAirportId, 300);
    expect(detail.flight.flightNumber, 'TP1019');

    expect(detail.timing.departure.status, FlightLocalTimeStatus.valid);
    expect(detail.timing.departure.utcOffsetMinutes, 60);

    expect(detail.timing.arrival.utcOffsetMinutes, 120);
    expect(detail.timing.durationMinutes, 115);
  });

  test('rejects missing timing', () {
    final json = flightJson()..remove('timing');

    expect(() => FlightDetail.fromJson(json), throwsFormatException);
  });

  test('rejects invalid timing', () {
    final json = flightJson()
      ..['timing'] = {
        'departure': {'status': 'valid', 'utc_offset_minutes': null},
        'arrival': {'status': 'valid', 'utc_offset_minutes': 120},
        'duration_minutes': 115,
      };

    expect(() => FlightDetail.fromJson(json), throwsFormatException);
  });
}
