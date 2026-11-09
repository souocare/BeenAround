import 'dart:async';

import 'package:beenaround/features/explore/application/country_trips_cubit.dart';
import 'package:beenaround/features/explore/application/country_trips_state.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountryTripsRepository extends Fake implements TripRepository {
  FakeCountryTripsRepository({this.trips = const [], this.shouldFail = false});

  List<Trip> trips;
  bool shouldFail;

  int calls = 0;
  String? receivedCountryCode;

  Future<List<Trip>> Function()? handler;

  @override
  Future<List<Trip>> getTripsForCountry({required String countryCode}) async {
    calls++;
    receivedCountryCode = countryCode;

    if (handler != null) {
      return handler!();
    }

    if (shouldFail) {
      throw StateError('Server unavailable.');
    }

    return trips;
  }
}

Trip makeTrip({required String id, required String name}) {
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
  test('starts in initial state', () {
    final repository = FakeCountryTripsRepository();

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    expect(cubit.state.phase, CountryTripsPhase.initial);
    expect(cubit.state.trips, isEmpty);
    expect(cubit.state.tripCount, 0);

    cubit.close();
  });

  test('loads associated trips for the selected country', () async {
    final repository = FakeCountryTripsRepository(
      trips: [
        makeTrip(id: 'trip-1', name: 'Portugal 2025'),
        makeTrip(id: 'trip-2', name: 'Portugal Road Trip'),
      ],
    );

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    await cubit.load();

    expect(repository.calls, 1);
    expect(repository.receivedCountryCode, 'PT');

    expect(cubit.state.phase, CountryTripsPhase.ready);
    expect(cubit.state.tripCount, 2);
    expect(cubit.state.trips.first.name, 'Portugal 2025');

    await cubit.close();
  });

  test('supports countries without associated trips', () async {
    final repository = FakeCountryTripsRepository();

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    await cubit.load();

    expect(cubit.state.phase, CountryTripsPhase.ready);
    expect(cubit.state.trips, isEmpty);
    expect(cubit.state.tripCount, 0);

    await cubit.close();
  });

  test('reports loading failures', () async {
    final repository = FakeCountryTripsRepository(shouldFail: true);

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    await cubit.load();

    expect(cubit.state.phase, CountryTripsPhase.failure);
    expect(cubit.state.errorMessage, 'Unable to load associated trips.');

    await cubit.close();
  });

  test('refresh retries after a failure', () async {
    final repository = FakeCountryTripsRepository(shouldFail: true);

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    await cubit.load();

    expect(cubit.state.phase, CountryTripsPhase.failure);

    repository.shouldFail = false;
    repository.trips = [makeTrip(id: 'trip-1', name: 'Portugal 2025')];

    await cubit.refresh();

    expect(repository.calls, 2);
    expect(cubit.state.phase, CountryTripsPhase.ready);
    expect(cubit.state.tripCount, 1);
    expect(cubit.state.errorMessage, isNull);

    await cubit.close();
  });

  test('ignores obsolete responses', () async {
    final repository = FakeCountryTripsRepository();

    final firstRequest = Completer<List<Trip>>();
    final secondRequest = Completer<List<Trip>>();

    var requestNumber = 0;

    repository.handler = () {
      requestNumber++;

      return requestNumber == 1 ? firstRequest.future : secondRequest.future;
    };

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    final firstLoad = cubit.load();
    final secondLoad = cubit.load();

    secondRequest.complete([makeTrip(id: 'trip-new', name: 'New Trip')]);

    await secondLoad;

    firstRequest.complete([makeTrip(id: 'trip-old', name: 'Old Trip')]);

    await firstLoad;

    expect(cubit.state.phase, CountryTripsPhase.ready);
    expect(cubit.state.trips.single.name, 'New Trip');

    await cubit.close();
  });

  test('ignores responses after closure', () async {
    final repository = FakeCountryTripsRepository();

    final request = Completer<List<Trip>>();

    repository.handler = () => request.future;

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    final loading = cubit.load();

    await cubit.close();

    request.complete([makeTrip(id: 'trip-1', name: 'Portugal 2025')]);

    await loading;

    expect(cubit.isClosed, isTrue);
  });

  test('returns an immutable trips list', () async {
    final repository = FakeCountryTripsRepository(
      trips: [makeTrip(id: 'trip-1', name: 'Portugal 2025')],
    );

    final cubit = CountryTripsCubit(repository: repository, countryCode: 'PT');

    await cubit.load();

    expect(() => cubit.state.trips.clear(), throwsUnsupportedError);

    await cubit.close();
  });
}
