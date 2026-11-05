import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/add_country_visit_cubit.dart';
import 'package:beenaround/features/explore/application/add_country_visit_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';

class FakeCountriesRepository implements CountriesRepository {
  int createCalls = 0;

  String? receivedCountryCode;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;
  VisitDatePrecision? receivedStartedOnPrecision;
  VisitDatePrecision? receivedEndedOnPrecision;

  Future<CountryVisit> Function()? createHandler;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError(
      'Country visit updates are not used by this test.',
    );
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError(
      'Country visit deletion is not used by this test.',
    );
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) {
    createCalls++;

    receivedCountryCode = countryCode;
    receivedStartedOn = startedOn;
    receivedEndedOn = endedOn;
    receivedStartedOnPrecision = startedOnPrecision;
    receivedEndedOnPrecision = endedOnPrecision;

    if (createHandler != null) {
      return createHandler!();
    }

    return Future.value(
      CountryVisit(
        id: 'visit-1',
        countryCode: countryCode,
        startedOn: startedOn,
        endedOn: endedOn,
        startedOnPrecision: startedOnPrecision,
        endedOnPrecision: endedOnPrecision,
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      ),
    );
  }
}

class FakeTripAssociationRepository extends Fake
    implements TripAssociationRepository {
  int addCountryCalls = 0;

  String? receivedTripId;
  String? receivedVisitId;

  Future<void> Function()? addHandler;

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    addCountryCalls++;

    receivedTripId = tripId;
    receivedVisitId = visitId;

    if (addHandler != null) {
      await addHandler!();
    }
  }
}

void main() {
  group('AddCountryVisitCubit', () {
    test('starts idle', () async {
      final cubit = AddCountryVisitCubit(repository: FakeCountriesRepository());

      expect(cubit.state.phase, AddCountryVisitPhase.idle);

      await cubit.close();
    });

    test('rejects a visit without dates', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(countryCode: 'PT');

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('creates a visit with exact dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final success = await cubit.submit(
        countryCode: 'ES',
        startedOn: start,
        endedOn: end,
      );

      expect(success, isTrue);
      expect(repository.receivedStartedOn, start);
      expect(repository.receivedEndedOn, end);

      await cubit.close();
    });

    test('rejects a missing end date', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'FR',
        startedOn: DateTime(2020, 5, 12),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('rejects missing country', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(countryCode: ' ');

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Please select a country.');

      await cubit.close();
    });

    test('rejects a missing start date', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('rejects end date earlier than start date', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOn: DateTime(2026, 10, 15),
        endedOn: DateTime(2026, 10, 10),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(
        cubit.state.errorMessage,
        'End date cannot be earlier than start date.',
      );

      await cubit.close();
    });

    test('ignores time of day when validating dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOn: DateTime(2026, 10, 15, 23),
        endedOn: DateTime(2026, 10, 15, 8),
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.createHandler = () => pending.future;

      final cubit = AddCountryVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final first = cubit.submit(
        countryCode: 'PT',
        startedOn: start,
        endedOn: end,
      );

      final second = await cubit.submit(
        countryCode: 'PT',
        startedOn: start,
        endedOn: end,
      );

      expect(second, isFalse);
      expect(repository.createCalls, 1);

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: start,
          endedOn: end,
          startedOnPrecision: VisitDatePrecision.day,
          endedOnPrecision: VisitDatePrecision.day,
          createdAt: DateTime(2026, 10, 21),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await first, isTrue);
      expect(cubit.state.phase, AddCountryVisitPhase.success);

      await cubit.close();
    });

    test('maps API errors to failure state', () async {
      final repository = FakeCountriesRepository();

      repository.createHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Server unavailable.',
        );
      };

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(cubit.state.phase, AddCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Server unavailable.');

      await cubit.close();
    });

    test('can retry after failure', () async {
      final repository = FakeCountriesRepository();

      repository.createHandler = () async {
        throw const FormatException('Invalid response');
      };

      final cubit = AddCountryVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final first = await cubit.submit(
        countryCode: 'PT',
        startedOn: start,
        endedOn: end,
      );

      expect(first, isFalse);
      expect(repository.createCalls, 1);

      repository.createHandler = null;

      cubit.clearError();

      expect(cubit.state.phase, AddCountryVisitPhase.idle);

      final second = await cubit.submit(
        countryCode: 'PT',
        startedOn: start,
        endedOn: end,
      );

      expect(second, isTrue);
      expect(repository.createCalls, 2);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.createHandler = () => pending.future;

      final cubit = AddCountryVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final submission = cubit.submit(
        countryCode: 'PT',
        startedOn: start,
        endedOn: end,
      );

      await cubit.close();

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: start,
          endedOn: end,
          startedOnPrecision: VisitDatePrecision.day,
          endedOnPrecision: VisitDatePrecision.day,
          createdAt: DateTime(2026, 10, 21),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await submission, isFalse);
    });
    test('creates a visit with month precision', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOn: DateTime(2024, 6, 1),
        endedOn: DateTime(2024, 8, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedStartedOn, DateTime(2024, 6, 1));
      expect(repository.receivedEndedOn, DateTime(2024, 8, 1));
      expect(repository.receivedStartedOnPrecision, VisitDatePrecision.month);
      expect(repository.receivedEndedOnPrecision, VisitDatePrecision.month);

      await cubit.close();
    });
    test('creates a visit with year precision', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOn: DateTime(2025, 1, 1),
        endedOnPrecision: VisitDatePrecision.year,
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedStartedOnPrecision, VisitDatePrecision.year);
      expect(repository.receivedEndedOnPrecision, VisitDatePrecision.year);

      await cubit.close();
    });
    test('rejects precision without a date', () async {
      final repository = FakeCountriesRepository();
      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        startedOnPrecision: VisitDatePrecision.month,
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(
        cubit.state.errorMessage,
        'A start date precision requires a start date.',
      );

      await cubit.close();
    });
    test('creates a visit without associating a Trip', () async {
      final countriesRepository = FakeCountriesRepository();

      final tripRepository = FakeTripAssociationRepository();

      final cubit = AddCountryVisitCubit(
        repository: countriesRepository,
        tripAssociationRepository: tripRepository,
      );

      final result = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
      );

      expect(result, isTrue);

      expect(countriesRepository.createCalls, 1);
      expect(tripRepository.addCountryCalls, 0);

      expect(cubit.state.phase, AddCountryVisitPhase.success);
      expect(cubit.state.createdVisitId, 'visit-1');
      expect(cubit.state.selectedTripId, isNull);

      await cubit.close();
    });
    test('creates a visit and associates it with a selected Trip', () async {
      final countriesRepository = FakeCountriesRepository();

      final tripRepository = FakeTripAssociationRepository();

      final cubit = AddCountryVisitCubit(
        repository: countriesRepository,
        tripAssociationRepository: tripRepository,
      );

      final result = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: 'trip-1',
      );

      expect(result, isTrue);

      expect(countriesRepository.createCalls, 1);
      expect(tripRepository.addCountryCalls, 1);

      expect(tripRepository.receivedTripId, 'trip-1');
      expect(tripRepository.receivedVisitId, 'visit-1');

      expect(cubit.state.phase, AddCountryVisitPhase.success);
      expect(cubit.state.createdVisitId, 'visit-1');
      expect(cubit.state.selectedTripId, 'trip-1');

      await cubit.close();
    });
    test('association failure preserves the created visit', () async {
      final countriesRepository = FakeCountriesRepository();

      final tripRepository = FakeTripAssociationRepository();

      tripRepository.addHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Server unavailable.',
          statusCode: 500,
        );
      };

      final cubit = AddCountryVisitCubit(
        repository: countriesRepository,
        tripAssociationRepository: tripRepository,
      );

      final firstResult = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: 'trip-1',
      );

      expect(firstResult, isFalse);

      expect(cubit.state.phase, AddCountryVisitPhase.associationFailure);

      expect(cubit.state.createdVisitId, 'visit-1');
      expect(cubit.state.selectedTripId, 'trip-1');

      expect(countriesRepository.createCalls, 1);
      expect(tripRepository.addCountryCalls, 1);

      // Submitting again must never create another visit.
      final duplicateResult = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: 'trip-1',
      );

      expect(duplicateResult, isFalse);
      expect(countriesRepository.createCalls, 1);

      // Clearing the error must not reset the partial success.
      cubit.clearError();

      expect(cubit.state.phase, AddCountryVisitPhase.associationFailure);

      // The backend becomes available again.
      tripRepository.addHandler = null;

      final retryResult = await cubit.retryAssociation();

      expect(retryResult, isTrue);

      expect(countriesRepository.createCalls, 1);
      expect(tripRepository.addCountryCalls, 2);

      expect(cubit.state.phase, AddCountryVisitPhase.success);

      await cubit.close();
    });
    test('prevents duplicate association submissions', () async {
      final countriesRepository = FakeCountriesRepository();

      final tripRepository = FakeTripAssociationRepository();

      final pending = Completer<void>();

      tripRepository.addHandler = () => pending.future;

      final cubit = AddCountryVisitCubit(
        repository: countriesRepository,
        tripAssociationRepository: tripRepository,
      );

      final first = cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: 'trip-1',
      );

      // Allow visit creation to complete and association to begin.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, AddCountryVisitPhase.associating);

      final second = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: 'trip-1',
      );

      expect(second, isFalse);

      expect(countriesRepository.createCalls, 1);
      expect(tripRepository.addCountryCalls, 1);

      pending.complete();

      expect(await first, isTrue);

      expect(cubit.state.phase, AddCountryVisitPhase.success);

      await cubit.close();
    });
    test('rejects an empty Trip ID before creating the visit', () async {
      final countriesRepository = FakeCountriesRepository();

      final tripRepository = FakeTripAssociationRepository();

      final cubit = AddCountryVisitCubit(
        repository: countriesRepository,
        tripAssociationRepository: tripRepository,
      );

      final result = await cubit.submit(
        countryCode: 'JP',
        startedOn: DateTime(2027, 4, 10),
        endedOn: DateTime(2027, 4, 25),
        tripId: '   ',
      );

      expect(result, isFalse);

      expect(countriesRepository.createCalls, 0);
      expect(tripRepository.addCountryCalls, 0);

      expect(cubit.state.phase, AddCountryVisitPhase.failure);

      await cubit.close();
    });
  });
}
