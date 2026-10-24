import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/delete_city_visit_cubit.dart';
import 'package:beenaround/features/explore/application/delete_city_visit_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int deleteCalls = 0;
  String? receivedVisitId;

  Future<void> Function()? deleteHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) async {
    deleteCalls++;
    receivedVisitId = visitId;

    if (deleteHandler != null) {
      await deleteHandler!();
    }
  }
}

void main() {
  group('DeleteCityVisitCubit', () {
    test('starts idle', () async {
      final cubit = DeleteCityVisitCubit(
        repository: FakeCityVisitsRepository(),
      );

      expect(cubit.state.phase, DeleteCityVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test('deletes a visit successfully', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = DeleteCityVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: 'visit-1');

      expect(success, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.receivedVisitId, 'visit-1');
      expect(cubit.state.phase, DeleteCityVisitPhase.success);

      await cubit.close();
    });

    test('trims visit ID before deletion', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = DeleteCityVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: ' visit-1 ');

      expect(success, isTrue);
      expect(repository.receivedVisitId, 'visit-1');

      await cubit.close();
    });

    test('rejects empty visit ID', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = DeleteCityVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: '   ');

      expect(success, isFalse);
      expect(repository.deleteCalls, 0);
      expect(cubit.state.phase, DeleteCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCityVisitsRepository();
      final pending = Completer<void>();

      repository.deleteHandler = () => pending.future;

      final cubit = DeleteCityVisitCubit(repository: repository);

      final first = cubit.delete(visitId: 'visit-1');
      final second = await cubit.delete(visitId: 'visit-1');

      expect(second, isFalse);
      expect(repository.deleteCalls, 1);
      expect(cubit.state.phase, DeleteCityVisitPhase.deleting);

      pending.complete();

      expect(await first, isTrue);
      expect(cubit.state.phase, DeleteCityVisitPhase.success);

      await cubit.close();
    });

    test('prevents deletion after success', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = DeleteCityVisitCubit(repository: repository);

      expect(await cubit.delete(visitId: 'visit-1'), isTrue);
      expect(await cubit.delete(visitId: 'visit-1'), isFalse);

      expect(repository.deleteCalls, 1);

      await cubit.close();
    });

    test('handles unexpected repository errors', () async {
      final repository = FakeCityVisitsRepository();

      repository.deleteHandler = () async {
        throw StateError('Unexpected error');
      };

      final cubit = DeleteCityVisitCubit(repository: repository);

      final success = await cubit.delete(visitId: 'visit-1');

      expect(success, isFalse);
      expect(cubit.state.phase, DeleteCityVisitPhase.failure);
      expect(
        cubit.state.errorMessage,
        'Unable to delete your visit. Please try again.',
      );

      await cubit.close();
    });

    test('clears errors', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = DeleteCityVisitCubit(repository: repository);

      await cubit.delete(visitId: '');

      expect(cubit.state.phase, DeleteCityVisitPhase.failure);

      cubit.clearError();

      expect(cubit.state.phase, DeleteCityVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test('does not emit after being closed', () async {
      final repository = FakeCityVisitsRepository();
      final pending = Completer<void>();

      repository.deleteHandler = () => pending.future;

      final cubit = DeleteCityVisitCubit(repository: repository);

      final deletion = cubit.delete(visitId: 'visit-1');

      await cubit.close();

      pending.complete();

      expect(await deletion, isFalse);
    });
  });
}
