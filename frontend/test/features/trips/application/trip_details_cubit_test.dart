import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/trips/application/trip_details_cubit.dart';
import 'package:beenaround/features/trips/application/trip_details_state.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';

class FakeTripDetailsRepository implements TripRepository {
  Future<Trip> Function(String id)? onGetTrip;

  int getTripCalls = 0;

  @override
  Future<Trip> getTrip({required String tripId}) {
    getTripCalls++;

    final handler = onGetTrip;

    if (handler == null) {
      throw UnimplementedError();
    }

    return handler(tripId);
  }

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<Trip> createTrip({required TripInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<Trip> updateTrip({required String tripId, required TripInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip({required String tripId}) {
    throw UnimplementedError();
  }
}

Trip testTrip(String name) {
  return Trip(
    id: 'trip-1',
    name: name,
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late FakeTripDetailsRepository repository;
  late TripDetailsCubit cubit;

  setUp(() {
    repository = FakeTripDetailsRepository();

    cubit = TripDetailsCubit(repository: repository, tripId: 'trip-1');
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state has no Trip', () {
    expect(cubit.state.phase, TripDetailsPhase.initial);
    expect(cubit.state.trip, isNull);
  });

  test('loads a Trip successfully', () async {
    repository.onGetTrip = (id) async {
      expect(id, 'trip-1');
      return testTrip('Japan 2027');
    };

    await cubit.load();

    expect(cubit.state.phase, TripDetailsPhase.ready);
    expect(cubit.state.trip?.name, 'Japan 2027');
    expect(repository.getTripCalls, 1);
  });

  test('maps API errors', () async {
    repository.onGetTrip = (_) async {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'The requested resource was not found.',
        statusCode: 404,
      );
    };

    await cubit.load();

    expect(cubit.state.phase, TripDetailsPhase.failure);
    expect(cubit.state.errorMessage, 'The requested resource was not found.');
  });

  test('refresh retrieves updated details', () async {
    var calls = 0;

    repository.onGetTrip = (_) async {
      calls++;

      return calls == 1 ? testTrip('Japan') : testTrip('Japan & Korea');
    };

    await cubit.load();

    expect(cubit.state.trip?.name, 'Japan');

    await cubit.refresh();

    expect(cubit.state.trip?.name, 'Japan & Korea');
  });

  test('old responses cannot overwrite newer details', () async {
    final first = Completer<Trip>();
    final second = Completer<Trip>();

    var calls = 0;

    repository.onGetTrip = (_) {
      calls++;

      return calls == 1 ? first.future : second.future;
    };

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    second.complete(testTrip('Updated Trip'));

    await secondLoad;

    first.complete(testTrip('Old Trip'));

    await firstLoad;

    expect(cubit.state.trip?.name, 'Updated Trip');
  });

  test('does not emit after closing', () async {
    final pending = Completer<Trip>();

    repository.onGetTrip = (_) => pending.future;

    final load = cubit.load();

    await cubit.close();

    pending.complete(testTrip('Japan'));

    await load;

    expect(cubit.isClosed, isTrue);
  });
}
