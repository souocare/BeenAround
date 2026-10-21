import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/add_country_visit_cubit.dart';
import 'package:beenaround/features/explore/application/add_country_visit_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountriesRepository implements CountriesRepository {
  int createCalls = 0;

  String? receivedCountryCode;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;

  Future<CountryVisit> Function()? createHandler;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
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
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    createCalls++;

    receivedCountryCode = countryCode;
    receivedStartedOn = startedOn;
    receivedEndedOn = endedOn;

    if (createHandler != null) {
      return createHandler!();
    }

    return Future.value(
      CountryVisit(
        id: 'visit-1',
        countryCode: countryCode,
        startedOn: startedOn,
        endedOn: endedOn,
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      ),
    );
  }
}

void main() {
  group('AddCountryVisitCubit', () {
    test('starts idle', () async {
      final cubit = AddCountryVisitCubit(repository: FakeCountriesRepository());

      expect(cubit.state.phase, AddCountryVisitPhase.idle);

      await cubit.close();
    });

    test('creates a visit without dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(countryCode: ' pt ');

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedCountryCode, 'PT');
      expect(repository.receivedStartedOn, isNull);
      expect(repository.receivedEndedOn, isNull);
      expect(cubit.state.phase, AddCountryVisitPhase.success);

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

    test('allows start date without end date', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'FR',
        startedOn: DateTime(2020, 5, 12),
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);

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

    test('rejects end date without start date', () async {
      final repository = FakeCountriesRepository();

      final cubit = AddCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        countryCode: 'PT',
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'An end date requires a start date.');

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

      final first = cubit.submit(countryCode: 'PT');
      final second = await cubit.submit(countryCode: 'PT');

      expect(second, isFalse);
      expect(repository.createCalls, 1);

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: null,
          endedOn: null,
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

      final success = await cubit.submit(countryCode: 'PT');

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

      expect(await cubit.submit(countryCode: 'PT'), isFalse);

      repository.createHandler = null;

      cubit.clearError();

      expect(cubit.state.phase, AddCountryVisitPhase.idle);

      expect(await cubit.submit(countryCode: 'PT'), isTrue);
      expect(repository.createCalls, 2);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCountriesRepository();

      final pending = Completer<CountryVisit>();

      repository.createHandler = () => pending.future;

      final cubit = AddCountryVisitCubit(repository: repository);

      final submission = cubit.submit(countryCode: 'PT');

      await cubit.close();

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: null,
          endedOn: null,
          createdAt: DateTime(2026, 10, 21),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await submission, isFalse);
    });
  });
}
