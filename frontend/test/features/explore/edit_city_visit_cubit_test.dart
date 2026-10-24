import 'dart:async';

import 'package:beenaround/features/explore/application/edit_city_visit_cubit.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int updateCalls = 0;

  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CityVisit> Function()? updateHandler;

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
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    return Future.value(
      CityVisit(
        id: visitId,
        cityId: 2267057,
        cityName: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        startedOn: changes['started_on'] as DateTime?,
        endedOn: changes['ended_on'] as DateTime?,
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 24),
      ),
    );
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

void main() {
  group('EditCityVisitCubit', () {
    test('starts idle', () async {
      final cubit = EditCityVisitCubit(repository: FakeCityVisitsRepository());

      expect(cubit.state.phase, EditCityVisitPhase.idle);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test('updates visit dates without changing city', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

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

      expect(repository.receivedChanges, {
        'started_on': start,
        'ended_on': end,
      });

      expect(repository.receivedChanges!.containsKey('city_id'), isFalse);

      expect(cubit.state.phase, EditCityVisitPhase.success);

      await cubit.close();
    });

    test('allows clearing both dates', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1');

      expect(success, isTrue);

      expect(repository.receivedChanges, {
        'started_on': null,
        'ended_on': null,
      });

      await cubit.close();
    });

    test('allows start date only', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final start = DateTime(2025, 6, 12);

      final success = await cubit.submit(visitId: 'visit-1', startedOn: start);

      expect(success, isTrue);

      expect(repository.receivedChanges, {
        'started_on': start,
        'ended_on': null,
      });

      await cubit.close();
    });

    test('allows end date only', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final end = DateTime(2025, 6, 15);

      final success = await cubit.submit(visitId: 'visit-1', endedOn: end);

      expect(success, isTrue);

      expect(repository.receivedChanges, {'started_on': null, 'ended_on': end});

      await cubit.close();
    });

    test('rejects missing visit ID', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: '  ');

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('rejects end date before start date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

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

    test('accepts same calendar day with different times', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

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
      final repository = FakeCityVisitsRepository();
      final pending = Completer<CityVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCityVisitCubit(repository: repository);

      final first = cubit.submit(visitId: 'visit-1');
      final second = await cubit.submit(visitId: 'visit-1');

      expect(second, isFalse);
      expect(repository.updateCalls, 1);
      expect(cubit.state.phase, EditCityVisitPhase.submitting);

      pending.complete(
        CityVisit(
          id: 'visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          startedOn: null,
          endedOn: null,
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 24),
        ),
      );

      expect(await first, isTrue);
      expect(cubit.state.phase, EditCityVisitPhase.success);

      await cubit.close();
    });
  });
}
