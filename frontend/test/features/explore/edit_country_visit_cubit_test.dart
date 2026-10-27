import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
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
  Map<String, dynamic>? receivedChanges;

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
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError();
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map<String, dynamic>.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    return Future.value(
      CountryVisit(
        id: visitId,
        countryCode: 'PT',
        startedOn: changes['started_on'] as DateTime?,
        endedOn: changes['ended_on'] as DateTime?,
        startedOnPrecision:
            changes['started_on_precision'] as VisitDatePrecision?,
        endedOnPrecision: changes['ended_on_precision'] as VisitDatePrecision?,
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

      final changes = {
        'started_on': start,
        'started_on_precision': VisitDatePrecision.day,
        'ended_on': end,
        'ended_on_precision': VisitDatePrecision.day,
      };

      final success = await cubit.submit(visitId: 'visit-1', changes: changes);

      expect(success, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.receivedVisitId, 'visit-1');
      expect(repository.receivedChanges, changes);
      expect(cubit.state.phase, EditCountryVisitPhase.success);

      await cubit.close();
    });

    test('updates only the end date without changing the start', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final end = DateTime(2026, 11, 1);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'ended_on': end,
          'ended_on_precision': VisitDatePrecision.month,
        },
      );

      expect(success, isTrue);
      expect(repository.receivedChanges, {
        'ended_on': end,
        'ended_on_precision': VisitDatePrecision.month,
      });
      expect(repository.receivedChanges!.containsKey('started_on'), isFalse);
      expect(
        repository.receivedChanges!.containsKey('started_on_precision'),
        isFalse,
      );

      await cubit.close();
    });

    test('supports year precision', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'started_on': DateTime(2024),
          'started_on_precision': VisitDatePrecision.year,
        },
      );

      expect(success, isTrue);
      expect(
        repository.receivedChanges!['started_on_precision'],
        VisitDatePrecision.year,
      );

      await cubit.close();
    });

    test('allows clearing both dates and precisions', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final changes = {
        'started_on': null,
        'started_on_precision': null,
        'ended_on': null,
        'ended_on_precision': null,
      };

      final success = await cubit.submit(visitId: 'visit-1', changes: changes);

      expect(success, isTrue);
      expect(repository.receivedChanges, changes);

      await cubit.close();
    });

    test('allows an end date without a start date', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final end = DateTime(2025, 6, 15);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'ended_on': end,
          'ended_on_precision': VisitDatePrecision.day,
        },
      );

      expect(success, isTrue);
      expect(repository.receivedChanges, {
        'ended_on': end,
        'ended_on_precision': VisitDatePrecision.day,
      });

      await cubit.close();
    });

    test('rejects missing visit ID', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: '  ',
        changes: {'started_on': DateTime(2026, 10, 10)},
      );

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('rejects empty changes', () async {
      final repository = FakeCountriesRepository();
      final cubit = EditCountryVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1', changes: {});

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'No changes to save.');

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCountryVisitCubit(repository: repository);

      final changes = {'started_on': DateTime(2026, 10, 10)};

      final first = cubit.submit(visitId: 'visit-1', changes: changes);

      final second = await cubit.submit(visitId: 'visit-1', changes: changes);

      expect(second, isFalse);
      expect(repository.updateCalls, 1);
      expect(cubit.state.phase, EditCountryVisitPhase.submitting);

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
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

      final changes = {'started_on': DateTime(2026, 10, 10)};

      expect(await cubit.submit(visitId: 'visit-1', changes: changes), isTrue);

      expect(await cubit.submit(visitId: 'visit-1', changes: changes), isFalse);

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

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {'started_on': DateTime(2026, 10, 10)},
      );

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

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {'started_on': DateTime(2026, 10, 10)},
      );

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

      final changes = {'started_on': DateTime(2026, 10, 10)};

      expect(await cubit.submit(visitId: 'visit-1', changes: changes), isFalse);

      repository.updateHandler = null;
      cubit.clearError();

      expect(cubit.state.phase, EditCountryVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      expect(await cubit.submit(visitId: 'visit-1', changes: changes), isTrue);

      expect(repository.updateCalls, 2);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<CountryVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCountryVisitCubit(repository: repository);

      final submission = cubit.submit(
        visitId: 'visit-1',
        changes: {'started_on': DateTime(2026, 10, 10)},
      );

      await cubit.close();

      pending.complete(
        CountryVisit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: null,
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 21),
        ),
      );

      expect(await submission, isFalse);
    });
  });
}
