import 'dart:async';

import 'package:beenaround/features/explore/application/city_trips_cubit.dart';
import 'package:beenaround/features/explore/application/city_trips_state.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityTripsRepository extends Fake implements TripRepository {
  FakeCityTripsRepository({this.trips = const [], this.shouldFail = false});

  List<Trip> trips;
  bool shouldFail;

  int calls = 0;
  int? receivedCityId;

  Future<List<Trip>> Function()? handler;

  @override
  Future<List<Trip>> getTripsForCity({required int cityId}) async {
    calls++;
    receivedCityId = cityId;

    if (handler != null) {
      return handler!();
    }

    if (shouldFail) {
      throw StateError('Server unavailable.');
    }

    return trips;
  }
}

Trip makeCityTrip({required String id, required String name}) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

void main() {
  const lisbonId = 2267057;

  test('starts in initial state', () async {
    final repository = FakeCityTripsRepository();

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    expect(cubit.state.phase, CityTripsPhase.initial);
    expect(cubit.state.trips, isEmpty);
    expect(cubit.state.tripCount, 0);
    expect(repository.calls, 0);

    await cubit.close();
  });

  test('loads Trips associated with the selected city', () async {
    final repository = FakeCityTripsRepository(
      trips: [
        makeCityTrip(id: 'trip-1', name: 'Lisbon 2025'),
        makeCityTrip(id: 'trip-2', name: 'Portugal Road Trip'),
      ],
    );

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(repository.calls, 1);
    expect(repository.receivedCityId, lisbonId);

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.tripCount, 2);

    expect(cubit.state.trips.map((trip) => trip.name).toList(), [
      'Lisbon 2025',
      'Portugal Road Trip',
    ]);

    await cubit.close();
  });

  test('supports cities without associated Trips', () async {
    final repository = FakeCityTripsRepository();

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.trips, isEmpty);
    expect(cubit.state.tripCount, 0);

    await cubit.close();
  });

  test('reports loading failures', () async {
    final repository = FakeCityTripsRepository(shouldFail: true);

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(cubit.state.phase, CityTripsPhase.failure);
    expect(cubit.state.trips, isEmpty);

    expect(cubit.state.errorMessage, 'Unable to load associated trips.');

    await cubit.close();
  });

  test('refresh retries after a failure', () async {
    final repository = FakeCityTripsRepository(shouldFail: true);

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(cubit.state.phase, CityTripsPhase.failure);

    repository.shouldFail = false;

    repository.trips = [makeCityTrip(id: 'trip-1', name: 'Lisbon 2025')];

    await cubit.refresh();

    expect(repository.calls, 2);

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.tripCount, 1);
    expect(cubit.state.errorMessage, isNull);

    await cubit.close();
  });

  test('ignores obsolete responses', () async {
    final repository = FakeCityTripsRepository();

    final firstRequest = Completer<List<Trip>>();
    final secondRequest = Completer<List<Trip>>();

    var requestNumber = 0;

    repository.handler = () {
      requestNumber++;

      return requestNumber == 1 ? firstRequest.future : secondRequest.future;
    };

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    secondRequest.complete([makeCityTrip(id: 'trip-new', name: 'New Trip')]);

    await secondLoad;

    firstRequest.complete([makeCityTrip(id: 'trip-old', name: 'Old Trip')]);

    await firstLoad;

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.trips.single.name, 'New Trip');

    await cubit.close();
  });

  test('ignores obsolete errors', () async {
    final repository = FakeCityTripsRepository();

    final firstRequest = Completer<List<Trip>>();
    final secondRequest = Completer<List<Trip>>();

    var requestNumber = 0;

    repository.handler = () {
      requestNumber++;

      return requestNumber == 1 ? firstRequest.future : secondRequest.future;
    };

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    secondRequest.complete([makeCityTrip(id: 'trip-new', name: 'Latest Trip')]);

    await secondLoad;

    firstRequest.completeError(StateError('Old request failed.'));

    await firstLoad;

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.trips.single.name, 'Latest Trip');
    expect(cubit.state.errorMessage, isNull);

    await cubit.close();
  });

  test('ignores responses after closure', () async {
    final repository = FakeCityTripsRepository();

    final request = Completer<List<Trip>>();

    repository.handler = () => request.future;

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    final loading = cubit.load();

    await cubit.close();

    request.complete([makeCityTrip(id: 'trip-1', name: 'Lisbon 2025')]);

    await loading;

    expect(cubit.isClosed, isTrue);
  });

  test('returns an immutable list', () async {
    final repository = FakeCityTripsRepository(
      trips: [makeCityTrip(id: 'trip-1', name: 'Lisbon 2025')],
    );

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(() => cubit.state.trips.clear(), throwsUnsupportedError);

    await cubit.close();
  });

  test('refresh replaces previously loaded Trips', () async {
    final repository = FakeCityTripsRepository(
      trips: [makeCityTrip(id: 'trip-1', name: 'Lisbon 2025')],
    );

    final cubit = CityTripsCubit(repository: repository, cityId: lisbonId);

    await cubit.load();

    expect(cubit.state.tripCount, 1);

    repository.trips = [];

    await cubit.refresh();

    expect(cubit.state.phase, CityTripsPhase.ready);
    expect(cubit.state.trips, isEmpty);
    expect(cubit.state.tripCount, 0);

    await cubit.close();
  });
}
