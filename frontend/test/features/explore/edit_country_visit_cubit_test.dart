import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/edit_country_visit_cubit.dart';
import 'package:beenaround/features/explore/application/edit_country_visit_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountriesRepository implements CountriesRepository {
  int updateCalls = 0;

  String? receivedVisitId;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;

  Future<CountryVisit> Function()? updateHandler;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError(
      'Country visit creation is not used by this test.',
    );
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError(
      'Country visit deletion is not used by this test.',
    );
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    updateCalls++;

    receivedVisitId = visitId;
    receivedStartedOn = startedOn;
    receivedEndedOn = endedOn;

    if (updateHandler != null) {
      return updateHandler!();
    }

    return Future.value(
      CountryVisit(
        id: visitId,
        countryCode: 'PT',
        startedOn: startedOn,
        endedOn: endedOn,
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 21),
      ),
    );
  }
}

void main() {
  group('EditCountryVisitCubit', () {
    test('starts idle', () async {
      final cubit = EditCountryVisitCubit(
        repository: FakeCountriesRepository(),
      );

      expect(cubit.state.phase, EditCountryVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test('updates a visit with exact dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final success = await cubit.submit(
        visitId: 'visit-1',
        startedOn: start,
        endedOn: end,
      );

      expect(success, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.receivedVisitId, 'visit-1');
      expect(repository.receivedStartedOn, start);
      expect(repository.receivedEndedOn, end);
      expect(cubit.state.phase, EditCountryVisitPhase.success);

      await cubit.close();
    });

    test('allows clearing both dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1');

      expect(success, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.receivedStartedOn, isNull);
      expect(repository.receivedEndedOn, isNull);
      expect(cubit.state.phase, EditCountryVisitPhase.success);

      await cubit.close();
    });

    test('allows start date without end date', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final start = DateTime(2025, 5, 12);

      final success = await cubit.submit(visitId: 'visit-1', startedOn: start);

      expect(success, isTrue);
      expect(repository.receivedStartedOn, start);
      expect(repository.receivedEndedOn, isNull);

      await cubit.close();
    });

    test('rejects missing visit ID', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: '  ');

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('rejects end date without start date', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: 'visit-1',
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.errorMessage, 'An end date requires a start date.');

      await cubit.close();
    });

    test('rejects end date earlier than start date', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: 'visit-1',
        startedOn: DateTime(2026, 10, 15),
        endedOn: DateTime(2026, 10, 10),
      );

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(
        cubit.state.errorMessage,
        'End date cannot be earlier than start date.',
      );

      await cubit.close();
    });

    test('ignores time of day when validating dates', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: 'visit-1',
        startedOn: DateTime(2026, 10, 15, 23),
        endedOn: DateTime(2026, 10, 15, 8),
      );

      expect(success, isTrue);
      expect(repository.updateCalls, 1);

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCountryVisitCubit(repository: repository);

      final first = cubit.submit(visitId: 'visit-1');
      final second = await cubit.submit(visitId: 'visit-1');

      expect(second, isFalse);
      expect(repository.updateCalls, 1);
      expect(cubit.state.phase, EditCountryVisitPhase.submitting);

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: null,
          endedOn: null,
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await first, isTrue);
      expect(cubit.state.phase, EditCountryVisitPhase.success);

      await cubit.close();
    });

    test('does not submit again after success', () async {
      final repository = FakeCountriesRepository();

      final cubit = EditCountryVisitCubit(repository: repository);

      expect(await cubit.submit(visitId: 'visit-1'), isTrue);
      expect(await cubit.submit(visitId: 'visit-1'), isFalse);

      expect(repository.updateCalls, 1);

      await cubit.close();
    });

    test('maps API errors to failure state', () async {
      final repository = FakeCountriesRepository();

      repository.updateHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Server unavailable.',
        );
      };

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1');

      expect(success, isFalse);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Server unavailable.');

      await cubit.close();
    });

    test('handles unexpected errors', () async {
      final repository = FakeCountriesRepository();

      repository.updateHandler = () async {
        throw const FormatException('Invalid response');
      };

      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1');

      expect(success, isFalse);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);
      expect(
        cubit.state.errorMessage,
        'Unable to update your visit. Please try again.',
      );

      await cubit.close();
    });

    test('can retry after failure', () async {
      final repository = FakeCountriesRepository();

      repository.updateHandler = () async {
        throw const FormatException('Invalid response');
      };

      final cubit = EditCountryVisitCubit(repository: repository);

      expect(await cubit.submit(visitId: 'visit-1'), isFalse);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);

      repository.updateHandler = null;

      cubit.clearError();

      expect(cubit.state.phase, EditCountryVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      expect(await cubit.submit(visitId: 'visit-1'), isTrue);
      expect(repository.updateCalls, 2);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCountryVisitCubit(repository: repository);

      final submission = cubit.submit(visitId: 'visit-1');

      await cubit.close();

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: null,
          endedOn: null,
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await submission, isFalse);
    });
  });
}
