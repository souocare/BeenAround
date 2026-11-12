import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes minimal flight creation input', () {
    const input = FlightCreateInput(
      departureAirportId: 100,
      arrivalAirportId: 200,
      departureOn: '2025-09-10',
      status: FlightStatus.flown,
    );

    expect(input.toJson(), {
      'departure_airport_id': 100,
      'arrival_airport_id': 200,
      'departure_on': '2025-09-10',
      'status': 'flown',
    });
  });

  test('serializes optional aviation details', () {
    const input = FlightCreateInput(
      departureAirportId: 100,
      arrivalAirportId: 200,
      departureOn: '2025-09-10',
      status: FlightStatus.flown,
      airlineId: 10,
      flightNumber: 'TP1920',
      seat: '12A',
      cabinClass: FlightCabinClass.economy,
    );

    final json = input.toJson();

    expect(json['airline_id'], 10);
    expect(json['flight_number'], 'TP1920');
    expect(json['seat'], '12A');
    expect(json['cabin_class'], 'economy');
  });

  test('creation input never includes user or Trip IDs', () {
    const input = FlightCreateInput(
      departureAirportId: 100,
      arrivalAirportId: 200,
      departureOn: '2025-09-10',
      status: FlightStatus.flown,
    );

    final json = input.toJson();

    expect(json.containsKey('user_id'), isFalse);
    expect(json.containsKey('trip_id'), isFalse);
  });

  test('patch preserves explicit null values', () {
    final patch = FlightPatch({
      'airline_id': null,
      'airline_name': 'Air Berlin',
    });

    expect(patch.toJson(), {'airline_id': null, 'airline_name': 'Air Berlin'});
  });

  test('patch rejects empty changes', () {
    expect(() => FlightPatch({}), throwsArgumentError);
  });

  test('patch rejects changes to ownership', () {
    expect(() => FlightPatch({'user_id': 'another-user'}), throwsArgumentError);
  });

  test('patch rejects changes to Trip associations', () {
    expect(() => FlightPatch({'trip_id': 'some-trip'}), throwsArgumentError);
  });

  test('patch rejects null for required fields', () {
    expect(() => FlightPatch({'departure_on': null}), throwsArgumentError);
  });

  test('patch snapshots its input', () {
    final changes = <String, dynamic>{'seat': '12A'};
    final patch = FlightPatch(changes);

    changes['seat'] = '14C';

    expect(patch.toJson()['seat'], '12A');
  });
}
