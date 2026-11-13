import 'package:beenaround/features/flights/application/save_flight_cubit.dart';
import 'package:beenaround/features/flights/application/save_flight_state.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

import 'package:flutter_test/flutter_test.dart';

class RecordingUpdateRepository extends Fake implements FlightRepository {
  RecordingUpdateRepository({required this.flight});

  final Flight flight;

  String? updatedFlightId;
  FlightPatch? receivedPatch;

  int updateCalls = 0;

  @override
  Future<Flight> updateFlight({
    required String flightId,
    required FlightPatch patch,
  }) async {
    updateCalls++;

    updatedFlightId = flightId;
    receivedPatch = patch;

    return flight;
  }
}

void main() {
  Flight makeFlight() {
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
      seat: '14A',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  group('SaveFlightCubit.update', () {
    late RecordingUpdateRepository repository;
    late SaveFlightCubit cubit;

    setUp(() {
      repository = RecordingUpdateRepository(flight: makeFlight());

      cubit = SaveFlightCubit(repository: repository);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('updates a flight using the provided patch', () async {
      final patch = FlightPatch({'seat': '14A'});

      final success = await cubit.update(flightId: 'flight-1', patch: patch);

      expect(success, isTrue);

      expect(repository.updateCalls, 1);
      expect(repository.updatedFlightId, 'flight-1');

      expect(repository.receivedPatch?.toJson(), {'seat': '14A'});

      expect(cubit.state.phase, SaveFlightPhase.success);
      expect(cubit.state.flight?.id, 'flight-1');
      expect(cubit.state.flight?.seat, '14A');
    });

    test('can clear an optional field', () async {
      final patch = FlightPatch({'seat': null});

      final success = await cubit.update(flightId: 'flight-1', patch: patch);

      expect(success, isTrue);

      expect(repository.receivedPatch?.toJson(), {'seat': null});
    });

    test('does not submit again after success', () async {
      final patch = FlightPatch({'seat': '14A'});

      final first = await cubit.update(flightId: 'flight-1', patch: patch);

      final second = await cubit.update(flightId: 'flight-1', patch: patch);

      expect(first, isTrue);
      expect(second, isFalse);

      expect(repository.updateCalls, 1);
    });

    test('can update again after reset', () async {
      final firstPatch = FlightPatch({'seat': '14A'});

      await cubit.update(flightId: 'flight-1', patch: firstPatch);

      cubit.reset();

      expect(cubit.state.phase, SaveFlightPhase.initial);

      final secondPatch = FlightPatch({'notes': 'Great flight!'});

      final second = await cubit.update(
        flightId: 'flight-1',
        patch: secondPatch,
      );

      expect(second, isTrue);
      expect(repository.updateCalls, 2);
    });
  });
}
