import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/delete_country_visit_cubit.dart';
import 'package:beenaround/features/explore/application/delete_country_visit_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

class FakeCountriesRepository implements CountriesRepository {
  int deleteCalls = 0;
  String? receivedVisitId;

  Future<void> Function()? deleteHandler;

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
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    deleteCalls++;
    receivedVisitId = visitId;

    if (deleteHandler != null) {
      return deleteHandler!();
    }

    return Future.value();
  }
}

void main() {
  group('DeleteCountryVisitCubit', () {
    test('starts idle', () async {
      final cubit = DeleteCountryVisitCubit(
        repository: FakeCountriesRepository(),
      );

      expect(cubit.state.phase, DeleteCountryVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test('deletes a visit successfully', () async {
      final repository = FakeCountriesRepository();

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: 'visit-1');

      expect(success, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.receivedVisitId, 'visit-1');
      expect(cubit.state.phase, DeleteCountryVisitPhase.success);

      await cubit.close();
    });

    test('trims visit ID before deletion', () async {
      final repository = FakeCountriesRepository();

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: ' visit-1 ');

      expect(success, isTrue);
      expect(repository.receivedVisitId, 'visit-1');

      await cubit.close();
    });

    test('rejects empty visit ID', () async {
      final repository = FakeCountriesRepository();

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: '   ');

      expect(success, isFalse);
      expect(repository.deleteCalls, 0);
      expect(cubit.state.phase, DeleteCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<void>();

      repository.deleteHandler = () => pending.future;

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final first = cubit.delete(visitId: 'visit-1');
      final second = await cubit.delete(visitId: 'visit-1');

      expect(second, isFalse);
      expect(repository.deleteCalls, 1);
      expect(cubit.state.phase, DeleteCountryVisitPhase.deleting);

      pending.complete();

      expect(await first, isTrue);
      expect(cubit.state.phase, DeleteCountryVisitPhase.success);

      await cubit.close();
    });

    test('does not delete again after success', () async {
      final repository = FakeCountriesRepository();

      final cubit = DeleteCountryVisitCubit(repository: repository);

      expect(await cubit.delete(visitId: 'visit-1'), isTrue);
      expect(await cubit.delete(visitId: 'visit-1'), isFalse);

      expect(repository.deleteCalls, 1);

      await cubit.close();
    });

    test('maps API errors to failure state', () async {
      final repository = FakeCountriesRepository();

      repository.deleteHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Server unavailable.',
        );
      };

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: 'visit-1');

      expect(success, isFalse);
      expect(cubit.state.phase, DeleteCountryVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Server unavailable.');

      await cubit.close();
    });

    test('handles unexpected errors', () async {
      final repository = FakeCountriesRepository();

      repository.deleteHandler = () async {
        throw StateError('Unexpected failure');
      };

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: 'visit-1');

      expect(success, isFalse);
      expect(cubit.state.phase, DeleteCountryVisitPhase.failure);
      expect(
        cubit.state.errorMessage,
        'Unable to delete your visit. Please try again.',
      );

      await cubit.close();
    });

    test('allows retry after failure', () async {
      final repository = FakeCountriesRepository();

      repository.deleteHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Temporary failure.',
        );
      };

      final cubit = DeleteCountryVisitCubit(repository: repository);

      expect(await cubit.delete(visitId: 'visit-1'), isFalse);

      repository.deleteHandler = null;

      cubit.clearError();

      expect(cubit.state.phase, DeleteCountryVisitPhase.idle);

      expect(await cubit.delete(visitId: 'visit-1'), isTrue);

      expect(repository.deleteCalls, 2);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCountriesRepository();
      final pending = Completer<void>();

      repository.deleteHandler = () => pending.future;

      final cubit = DeleteCountryVisitCubit(repository: repository);

      final submission = cubit.delete(visitId: 'visit-1');

      await cubit.close();

      pending.complete();

      expect(await submission, isFalse);
    });

    test('does not submit after close', () async {
      final repository = FakeCountriesRepository();

      final cubit = DeleteCountryVisitCubit(repository: repository);

      await cubit.close();

      expect(await cubit.delete(visitId: 'visit-1'), isFalse);

      expect(repository.deleteCalls, 0);
    });
  });
}
