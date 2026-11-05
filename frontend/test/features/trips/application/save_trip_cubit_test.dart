import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/trips/application/save_trip_cubit.dart';
import 'package:beenaround/features/trips/application/save_trip_state.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';

import 'package:flutter_test/flutter_test.dart';

class FakeSaveTripRepository implements TripRepository {
  Future<Trip> Function(TripInput input)? onCreate;

  Future<Trip> Function(String tripId, TripInput input)? onUpdate;

  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<Trip> createTrip({required TripInput input}) {
    createCalls++;

    final handler = onCreate;

    if (handler == null) {
      throw UnimplementedError('Create handler not configured.');
    }

    return handler(input);
  }

  @override
  Future<Trip> updateTrip({required String tripId, required TripInput input}) {
    updateCalls++;

    final handler = onUpdate;

    if (handler == null) {
      throw UnimplementedError('Update handler not configured.');
    }

    return handler(tripId, input);
  }

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<Trip> getTrip({required String tripId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip({required String tripId}) {
    throw UnimplementedError();
  }
}

Trip persistedTrip({String id = 'trip-1', String name = 'Japan 2027'}) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 11, 5),
    updatedAt: DateTime(2026, 11, 5),
  );
}

void main() {
  late FakeSaveTripRepository repository;
  late SaveTripCubit cubit;

  setUp(() {
    repository = FakeSaveTripRepository();

    cubit = SaveTripCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('starts in the initial state', () {
    expect(cubit.state.phase, SaveTripPhase.initial);
    expect(cubit.state.trip, isNull);
    expect(cubit.state.errorMessage, isNull);
  });

  test('creates a Trip successfully', () async {
    repository.onCreate = (input) async {
      expect(input.name, 'Japan 2027');

      return persistedTrip();
    };

    await cubit.create(input: const TripInput(name: 'Japan 2027'));

    expect(cubit.state.phase, SaveTripPhase.success);
    expect(cubit.state.trip?.id, 'trip-1');
    expect(cubit.state.trip?.name, 'Japan 2027');
    expect(cubit.state.errorMessage, isNull);

    expect(repository.createCalls, 1);
    expect(repository.updateCalls, 0);
  });

  test('updates an existing Trip successfully', () async {
    repository.onUpdate = (tripId, input) async {
      expect(tripId, 'trip-1');
      expect(input.name, 'Japan & Korea 2027');

      return persistedTrip(name: 'Japan & Korea 2027');
    };

    await cubit.update(
      tripId: 'trip-1',
      input: const TripInput(name: 'Japan & Korea 2027'),
    );

    expect(cubit.state.phase, SaveTripPhase.success);
    expect(cubit.state.trip?.name, 'Japan & Korea 2027');

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 1);
  });

  test('rejects a blank Trip name without calling repository', () async {
    await cubit.create(input: const TripInput(name: '   '));

    expect(cubit.state.phase, SaveTripPhase.failure);
    expect(cubit.state.errorMessage, contains('Trip name'));

    expect(repository.createCalls, 0);
  });

  test('rejects an invalid Trip ID before updating', () async {
    await cubit.update(
      tripId: '   ',
      input: const TripInput(name: 'Japan'),
    );

    expect(cubit.state.phase, SaveTripPhase.failure);
    expect(cubit.state.errorMessage, 'Invalid Trip identifier.');

    expect(repository.updateCalls, 0);
  });

  test('maps API validation errors to failure state', () async {
    repository.onCreate = (_) async {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'The provided information is invalid.',
        statusCode: 422,
      );
    };

    await cubit.create(input: const TripInput(name: 'Japan'));

    expect(cubit.state.phase, SaveTripPhase.failure);
    expect(cubit.state.errorMessage, 'The provided information is invalid.');
  });

  test('maps authentication errors to failure state', () async {
    repository.onCreate = (_) async {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Authentication is required.',
        statusCode: 401,
      );
    };

    await cubit.create(input: const TripInput(name: 'Japan'));

    expect(cubit.state.phase, SaveTripPhase.failure);
    expect(cubit.state.errorMessage, 'Authentication is required.');
  });

  test('maps unexpected exceptions to a safe message', () async {
    repository.onCreate = (_) async {
      throw StateError('Internal implementation details.');
    };

    await cubit.create(input: const TripInput(name: 'Japan'));

    expect(cubit.state.phase, SaveTripPhase.failure);
    expect(
      cubit.state.errorMessage,
      'Unable to save your Trip. Please try again.',
    );
  });

  test('prevents duplicate submissions while saving', () async {
    final pending = Completer<Trip>();

    repository.onCreate = (_) => pending.future;

    final firstSave = cubit.create(input: const TripInput(name: 'Japan'));

    expect(cubit.state.phase, SaveTripPhase.submitting);

    final secondSave = cubit.create(input: const TripInput(name: 'Japan'));

    expect(repository.createCalls, 1);

    pending.complete(persistedTrip());

    await Future.wait([firstSave, secondSave]);

    expect(repository.createCalls, 1);
    expect(cubit.state.phase, SaveTripPhase.success);
  });

  test('allows retry after a failed submission', () async {
    var attempts = 0;

    repository.onCreate = (_) async {
      attempts++;

      if (attempts == 1) {
        throw Exception('Temporary failure');
      }

      return persistedTrip();
    };

    const input = TripInput(name: 'Japan');

    await cubit.create(input: input);

    expect(cubit.state.phase, SaveTripPhase.failure);

    await cubit.create(input: input);

    expect(cubit.state.phase, SaveTripPhase.success);
    expect(repository.createCalls, 2);
  });

  test('does not emit a late success after closing', () async {
    final pending = Completer<Trip>();

    repository.onCreate = (_) => pending.future;

    final save = cubit.create(input: const TripInput(name: 'Japan'));

    expect(cubit.state.phase, SaveTripPhase.submitting);

    await cubit.close();

    pending.complete(persistedTrip());

    await save;

    expect(cubit.isClosed, isTrue);
  });

  test('does not start a new operation after closing', () async {
    await cubit.close();

    await cubit.create(input: const TripInput(name: 'Japan'));

    expect(repository.createCalls, 0);
  });
}
