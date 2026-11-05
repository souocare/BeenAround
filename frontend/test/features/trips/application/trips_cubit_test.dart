import 'dart:async';

import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/trips/application/trips_cubit.dart';
import 'package:beenaround/features/trips/application/trips_state.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';

class FakeTripRepository implements TripRepository {
  Future<List<Trip>> Function()? onGetTrips;

  @override
  Future<List<Trip>> getTrips() {
    return onGetTrips?.call() ?? Future.value([]);
  }

  @override
  Future<Trip> getTrip({required String tripId}) {
    throw UnimplementedError();
  }

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

Trip testTrip(String id) {
  return Trip(
    id: id,
    name: 'Test Trip $id',
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late FakeTripRepository repository;
  late TripsCubit cubit;

  setUp(() {
    repository = FakeTripRepository();

    cubit = TripsCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state is empty', () {
    expect(cubit.state.phase, TripsPhase.initial);
    expect(cubit.state.trips, isEmpty);
  });

  test('successful load stores Trips', () async {
    repository.onGetTrips = () async => [testTrip('1'), testTrip('2')];

    await cubit.load();

    expect(cubit.state.phase, TripsPhase.ready);
    expect(cubit.state.totalTrips, 2);
    expect(cubit.state.errorMessage, isNull);
  });

  test('empty response produces ready state', () async {
    repository.onGetTrips = () async => [];

    await cubit.load();

    expect(cubit.state.phase, TripsPhase.ready);
    expect(cubit.state.trips, isEmpty);
  });

  test('failure produces error state', () async {
    repository.onGetTrips = () async {
      throw Exception('Connection failed');
    };

    await cubit.load();

    expect(cubit.state.phase, TripsPhase.failure);
    expect(cubit.state.errorMessage, 'Unable to load your Trips.');
  });

  test('refresh loads updated Trips', () async {
    var requestCount = 0;

    repository.onGetTrips = () async {
      requestCount++;

      if (requestCount == 1) {
        return [testTrip('1')];
      }

      return [testTrip('1'), testTrip('2')];
    };

    await cubit.load();

    expect(cubit.state.totalTrips, 1);

    await cubit.refresh();

    expect(cubit.state.totalTrips, 2);
    expect(requestCount, 2);
  });

  test('old response cannot overwrite a newer response', () async {
    final first = Completer<List<Trip>>();
    final second = Completer<List<Trip>>();

    var requests = 0;

    repository.onGetTrips = () {
      requests++;

      return requests == 1 ? first.future : second.future;
    };

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    second.complete([testTrip('new')]);

    await secondLoad;

    expect(cubit.state.trips.single.id, 'new');

    first.complete([testTrip('old')]);

    await firstLoad;

    expect(cubit.state.trips.single.id, 'new');
  });

  test('closing Cubit prevents late updates', () async {
    final pending = Completer<List<Trip>>();

    repository.onGetTrips = () => pending.future;

    final load = cubit.load();

    await cubit.close();

    pending.complete([testTrip('1')]);

    await load;

    expect(cubit.isClosed, isTrue);
  });
}
