import 'dart:async';

import 'package:beenaround/features/flights/application/delete_flight_cubit.dart';
import 'package:beenaround/features/flights/application/delete_flight_state.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

import 'package:flutter_test/flutter_test.dart';

class RecordingDeleteRepository extends Fake implements FlightRepository {
  int deleteCalls = 0;
  String? lastDeletedFlightId;

  Completer<void>? pendingDeletion;
  bool shouldFail = false;

  @override
  Future<void> deleteFlight({required String flightId}) async {
    deleteCalls++;
    lastDeletedFlightId = flightId;

    if (shouldFail) {
      throw StateError('Simulated deletion failure');
    }

    final pending = pendingDeletion;

    if (pending != null) {
      await pending.future;
    }
  }
}

void main() {
  group('DeleteFlightCubit', () {
    late RecordingDeleteRepository repository;
    late DeleteFlightCubit cubit;

    setUp(() {
      repository = RecordingDeleteRepository();

      cubit = DeleteFlightCubit(repository: repository);
    });

    tearDown(() async {
      if (repository.pendingDeletion case final pending?) {
        if (!pending.isCompleted) {
          pending.complete();
        }
      }

      await cubit.close();
    });

    test('starts in initial state', () {
      expect(cubit.state.phase, DeleteFlightPhase.initial);

      expect(cubit.state.isDeleting, isFalse);
      expect(cubit.state.hasError, isFalse);
    });

    test('deletes the requested flight', () async {
      final success = await cubit.deleteFlight('flight-123');

      expect(success, isTrue);

      expect(repository.deleteCalls, 1);
      expect(repository.lastDeletedFlightId, 'flight-123');

      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.hasError, isFalse);
    });

    test('reports failure without marking deletion successful', () async {
      repository.shouldFail = true;

      final success = await cubit.deleteFlight('flight-123');

      expect(success, isFalse);

      expect(repository.deleteCalls, 1);

      expect(cubit.state.phase, DeleteFlightPhase.failure);

      expect(cubit.state.errorMessage, 'Unable to delete your flight.');
    });

    test('prevents duplicate requests while deleting', () async {
      repository.pendingDeletion = Completer<void>();

      final first = cubit.deleteFlight('flight-123');

      expect(cubit.state.isDeleting, isTrue);

      final second = await cubit.deleteFlight('flight-123');

      expect(second, isFalse);
      expect(repository.deleteCalls, 1);

      repository.pendingDeletion!.complete();

      expect(await first, isTrue);

      expect(repository.deleteCalls, 1);
      expect(cubit.state.isSuccess, isTrue);
    });

    test('prevents deleting again after success', () async {
      final first = await cubit.deleteFlight('flight-123');

      final second = await cubit.deleteFlight('flight-123');

      expect(first, isTrue);
      expect(second, isFalse);

      expect(repository.deleteCalls, 1);
    });

    test('allows retry after failure', () async {
      repository.shouldFail = true;

      final first = await cubit.deleteFlight('flight-123');

      expect(first, isFalse);
      expect(cubit.state.hasError, isTrue);

      repository.shouldFail = false;

      final second = await cubit.deleteFlight('flight-123');

      expect(second, isTrue);

      expect(repository.deleteCalls, 2);
      expect(cubit.state.isSuccess, isTrue);
    });

    test('does not emit success after Cubit closes', () async {
      repository.pendingDeletion = Completer<void>();

      final deletion = cubit.deleteFlight('flight-123');

      expect(cubit.state.isDeleting, isTrue);

      await cubit.close();

      repository.pendingDeletion!.complete();

      expect(await deletion, isFalse);
      expect(repository.deleteCalls, 1);
    });
  });
}
