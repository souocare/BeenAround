import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/trips/application/save_trip_cubit.dart';
import 'package:beenaround/features/trips/application/save_trip_state.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

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
  Future<List<Trip>> getTripsForCountry({required String countryCode}) {
    throw UnimplementedError('Country Trips are not exercised by this test.');
  }

  @override
  Future<List<Trip>> getTripsForCity({required int cityId}) {
    throw UnimplementedError('City Trips are not exercised by this test.');
  }

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

class FakeSaveTripAssociationRepository implements TripAssociationRepository {
  final List<String> addedCountries = [];
  final List<String> addedCities = [];

  int? failOnCountryCall;
  int? failOnCityCall;

  int countryCalls = 0;
  int cityCalls = 0;

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    countryCalls++;

    if (failOnCountryCall == countryCalls) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Unable to associate country visit.',
        statusCode: 500,
      );
    }

    addedCountries.add(visitId);
  }

  @override
  Future<void> addCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    cityCalls++;

    if (failOnCityCall == cityCalls) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Unable to associate city visit.',
        statusCode: 500,
      );
    }

    addedCities.add(visitId);
  }

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) async =>
      [];

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) async => [];

  @override
  Future<void> removeCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    throw UnimplementedError();
  }
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
  test('creates a Trip and associates selected visits', () async {
    final associations = FakeSaveTripAssociationRepository();

    final tripCubit = SaveTripCubit(
      repository: repository,
      associationRepository: associations,
    );

    addTearDown(tripCubit.close);

    repository.onCreate = (_) async => persistedTrip();

    await tripCubit.createWithVisits(
      input: const TripInput(name: 'Japan 2027'),
      countryVisitIds: ['country-1'],
      cityVisitIds: ['city-1', 'city-2'],
    );

    expect(repository.createCalls, 1);

    expect(associations.addedCountries, ['country-1']);
    expect(associations.addedCities, ['city-1', 'city-2']);

    expect(tripCubit.state.phase, SaveTripPhase.success);
    expect(tripCubit.state.trip?.id, 'trip-1');
  });
  test('partial association failure never recreates the Trip', () async {
    final associations = FakeSaveTripAssociationRepository()
      ..failOnCityCall = 1;

    final tripCubit = SaveTripCubit(
      repository: repository,
      associationRepository: associations,
    );

    addTearDown(tripCubit.close);

    repository.onCreate = (_) async => persistedTrip();

    await tripCubit.createWithVisits(
      input: const TripInput(name: 'Japan 2027'),
      countryVisitIds: ['country-1'],
      cityVisitIds: ['city-1'],
    );

    expect(repository.createCalls, 1);

    expect(tripCubit.state.phase, SaveTripPhase.partialFailure);
    expect(tripCubit.state.trip?.id, 'trip-1');

    expect(tripCubit.state.pendingCountryVisitIds, isEmpty);

    expect(tripCubit.state.pendingCityVisitIds, ['city-1']);

    associations.failOnCityCall = null;

    await tripCubit.retryPendingAssociations();

    expect(repository.createCalls, 1);
    expect(associations.addedCountries, ['country-1']);
    expect(associations.addedCities, ['city-1']);

    expect(tripCubit.state.phase, SaveTripPhase.success);
  });
  test('creates a Trip without selected visits', () async {
    final associations = FakeSaveTripAssociationRepository();

    final tripCubit = SaveTripCubit(
      repository: repository,
      associationRepository: associations,
    );

    addTearDown(tripCubit.close);

    repository.onCreate = (_) async => persistedTrip();

    await tripCubit.createWithVisits(
      input: const TripInput(name: 'Japan 2027'),
      countryVisitIds: [],
      cityVisitIds: [],
    );

    expect(repository.createCalls, 1);

    expect(associations.countryCalls, 0);
    expect(associations.cityCalls, 0);

    expect(tripCubit.state.phase, SaveTripPhase.success);
  });
}
