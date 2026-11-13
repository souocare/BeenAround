import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/flights/domain/flight_patch_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Flight originalFlight() {
    final timestamp = DateTime.utc(2026, 10, 10);

    return Flight(
      id: 'flight-1',
      departureAirportId: 100,
      arrivalAirportId: 300,
      departureOn: '2026-10-10',
      departureTime: '19:20:00',
      arrivalOn: '2026-10-10',
      arrivalTime: '22:15:00',
      status: FlightStatus.flown,
      airlineId: 10,
      flightNumber: 'TP1019',
      seat: '12A',
      cabinClass: FlightCabinClass.economy,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  FlightCreateInput editedFlight({
    int departureAirportId = 100,
    int arrivalAirportId = 300,
    int? airlineId = 10,
    String? airlineName,
    String? seat = '12A',
    String? notes,
  }) {
    return FlightCreateInput(
      departureAirportId: departureAirportId,
      arrivalAirportId: arrivalAirportId,
      departureOn: '2026-10-10',
      departureTime: '19:20',
      arrivalOn: '2026-10-10',
      arrivalTime: '22:15',
      status: FlightStatus.flown,
      airlineId: airlineId,
      airlineName: airlineName,
      flightNumber: 'TP1019',
      seat: seat,
      cabinClass: FlightCabinClass.economy,
      notes: notes,
    );
  }

  group('FlightPatchBuilder', () {
    test('returns null when nothing changed', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(),
      );

      expect(patch, isNull);
    });

    test('updates only the changed seat', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(seat: '14A'),
      );

      expect(patch?.toJson(), {'seat': '14A'});
    });

    test('clears an optional field explicitly', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(seat: null),
      );

      expect(patch?.toJson(), {'seat': null});
    });

    test('changes only the departure airport', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(departureAirportId: 200),
      );

      expect(patch?.toJson(), {'departure_airport_id': 200});
    });

    test('switches from catalog to manual airline', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(airlineId: null, airlineName: 'Air Berlin'),
      );

      expect(patch?.toJson(), {
        'airline_id': null,
        'airline_name': 'Air Berlin',
      });
    });

    test('removes the selected airline', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(airlineId: null),
      );

      expect(patch?.toJson(), {'airline_id': null, 'airline_name': null});
    });

    test('does not modify an unchanged airline', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(notes: 'Great flight!'),
      );

      expect(patch?.toJson(), {'notes': 'Great flight!'});
    });

    test('ignores equivalent time formatting', () {
      final patch = FlightPatchBuilder.build(
        original: originalFlight(),
        edited: editedFlight(),
      );

      expect(patch, isNull);
    });
  });
}
