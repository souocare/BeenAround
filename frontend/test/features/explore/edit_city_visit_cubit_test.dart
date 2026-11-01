import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_cubit.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
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
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
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
      CityVisit(
        id: visitId,
        cityId: 2267057,
        cityName: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        startedOn: changes['started_on'] as DateTime?,
        endedOn: changes['ended_on'] as DateTime?,
        startedOnPrecision:
            changes['started_on_precision'] as VisitDatePrecision?,
        endedOnPrecision: changes['ended_on_precision'] as VisitDatePrecision?,
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

CountryVisitDateExpansion sampleExpansion() {
  return CountryVisitDateExpansion.fromJson({
    'country_visit_id': '550e8400-e29b-41d4-a716-446655440001',
    'current': {
      'started_on': '2025-06-10',
      'started_on_precision': 'day',
      'ended_on': '2025-06-15',
      'ended_on_precision': 'day',
    },
    'proposed': {
      'started_on': '2025-06-10',
      'started_on_precision': 'day',
      'ended_on': '2025-06-18',
      'ended_on_precision': 'day',
    },
  });
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
      expect(repository.receivedChanges!.containsKey('city_id'), isFalse);
      expect(cubit.state.phase, EditCityVisitPhase.success);

      await cubit.close();
    });

    test('updates only the end date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

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

      await cubit.close();
    });

    test('supports year precision', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

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

    test('rejects clearing visit dates', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'started_on': null,
          'started_on_precision': null,
          'ended_on': null,
          'ended_on_precision': null,
        },
      );

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Visit dates cannot be cleared.');

      await cubit.close();
    });

    test('updates only the start date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final start = DateTime(2025, 6, 12);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {'started_on': start},
      );

      expect(success, isTrue);
      expect(repository.receivedChanges, {'started_on': start});

      await cubit.close();
    });

    test('updates only the end date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final end = DateTime(2025, 6, 15);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {'ended_on': end},
      );

      expect(success, isTrue);
      expect(repository.receivedChanges, {'ended_on': end});

      await cubit.close();
    });

    test('rejects missing visit ID', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        visitId: '  ',
        changes: {'started_on': DateTime(2026, 10, 10)},
      );

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.phase, EditCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Invalid visit.');

      await cubit.close();
    });

    test('rejects empty changes', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = EditCityVisitCubit(repository: repository);

      final success = await cubit.submit(visitId: 'visit-1', changes: {});

      expect(success, isFalse);
      expect(repository.updateCalls, 0);
      expect(cubit.state.errorMessage, 'No changes to save.');

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCityVisitsRepository();
      final pending = Completer<CityVisit>();

      repository.updateHandler = () => pending.future;

      final cubit = EditCityVisitCubit(repository: repository);

      final changes = {'started_on': DateTime(2026, 10, 10)};

      final first = cubit.submit(visitId: 'visit-1', changes: changes);

      final second = await cubit.submit(visitId: 'visit-1', changes: changes);

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
          startedOn: DateTime(2026, 10, 10),
          endedOn: null,
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 24),
        ),
      );

      expect(await first, isTrue);
      expect(cubit.state.phase, EditCityVisitPhase.success);

      await cubit.close();
    });
    test(
      'stores an expansion proposal without automatic confirmation',
      () async {
        final expansion = sampleExpansion();

        final repository = FakeCityVisitsRepository()
          ..updateHandler = () async {
            throw CountryVisitDateExpansionRequired(expansion);
          };

        final cubit = EditCityVisitCubit(repository: repository);

        final success = await cubit.submit(
          visitId: 'visit-1',
          changes: {'country_visit_id': expansion.countryVisitId},
        );

        expect(success, isFalse);
        expect(cubit.state.phase, EditCityVisitPhase.expansionRequired);
        expect(cubit.state.pendingExpansion, same(expansion));
        expect(cubit.state.errorMessage, isNull);
        expect(repository.updateCalls, 1);

        await cubit.close();
      },
    );
    test('submits the original update after explicit confirmation', () async {
      final expansion = sampleExpansion();
      final repository = FakeCityVisitsRepository();

      repository.updateHandler = () async {
        if (repository.updateCalls == 1) {
          throw CountryVisitDateExpansionRequired(expansion);
        }

        return CityVisit(
          id: 'visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          countryVisitId: expansion.countryVisitId,
          startedOn: DateTime(2025, 6, 12),
          endedOn: DateTime(2025, 6, 18),
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 24),
        );
      };

      final cubit = EditCityVisitCubit(repository: repository);

      final changes = {'country_visit_id': expansion.countryVisitId};

      await cubit.submit(visitId: 'visit-1', changes: changes);

      expect(cubit.state.phase, EditCityVisitPhase.expansionRequired);
      expect(repository.updateCalls, 1);

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: changes,
        countryDateExpansion: cubit.state.pendingExpansion,
      );

      expect(success, isTrue);
      expect(cubit.state.phase, EditCityVisitPhase.success);
      expect(repository.updateCalls, 2);
      expect(
        repository.receivedChanges!['country_visit_id'],
        expansion.countryVisitId,
      );
      expect(
        repository.receivedChanges!['country_date_expansion'],
        same(expansion),
      );

      await cubit.close();
    });
    test('rejects expansion confirmation after changing the update', () async {
      final expansion = sampleExpansion();

      final repository = FakeCityVisitsRepository()
        ..updateHandler = () async {
          throw CountryVisitDateExpansionRequired(expansion);
        };

      final cubit = EditCityVisitCubit(repository: repository);

      await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'country_visit_id': expansion.countryVisitId,
          'ended_on': DateTime(2025, 6, 18),
        },
      );

      final success = await cubit.submit(
        visitId: 'visit-1',
        changes: {
          'country_visit_id': expansion.countryVisitId,
          'ended_on': DateTime(2025, 6, 20),
        },
        countryDateExpansion: cubit.state.pendingExpansion,
      );

      expect(success, isFalse);
      expect(cubit.state.phase, EditCityVisitPhase.failure);
      expect(repository.updateCalls, 1);

      await cubit.close();
    });
    test('rejects confirmation for a different city visit', () async {
      final expansion = sampleExpansion();

      final repository = FakeCityVisitsRepository()
        ..updateHandler = () async {
          throw CountryVisitDateExpansionRequired(expansion);
        };

      final cubit = EditCityVisitCubit(repository: repository);

      await cubit.submit(
        visitId: 'visit-1',
        changes: {'country_visit_id': expansion.countryVisitId},
      );

      final success = await cubit.submit(
        visitId: 'visit-2',
        changes: {'country_visit_id': expansion.countryVisitId},
        countryDateExpansion: cubit.state.pendingExpansion,
      );

      expect(success, isFalse);
      expect(cubit.state.phase, EditCityVisitPhase.failure);
      expect(repository.updateCalls, 1);

      await cubit.close();
    });
    test(
      'dismisses an expansion proposal without updating the visit',
      () async {
        final expansion = sampleExpansion();

        final repository = FakeCityVisitsRepository()
          ..updateHandler = () async {
            throw CountryVisitDateExpansionRequired(expansion);
          };

        final cubit = EditCityVisitCubit(repository: repository);

        await cubit.submit(
          visitId: 'visit-1',
          changes: {'country_visit_id': expansion.countryVisitId},
        );

        expect(cubit.state.phase, EditCityVisitPhase.expansionRequired);

        cubit.dismissExpansion();

        expect(cubit.state.phase, EditCityVisitPhase.idle);
        expect(cubit.state.pendingExpansion, isNull);
        expect(repository.updateCalls, 1);

        await cubit.close();
      },
    );
    test('does not mutate the original changes when confirming', () async {
      final expansion = sampleExpansion();
      final repository = FakeCityVisitsRepository();

      repository.updateHandler = () async {
        if (repository.updateCalls == 1) {
          throw CountryVisitDateExpansionRequired(expansion);
        }

        return CityVisit(
          id: 'visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          startedOn: DateTime(2025, 6, 12),
          endedOn: DateTime(2025, 6, 18),
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 24),
        );
      };

      final cubit = EditCityVisitCubit(repository: repository);

      final changes = <String, dynamic>{
        'country_visit_id': expansion.countryVisitId,
      };

      await cubit.submit(visitId: 'visit-1', changes: changes);

      await cubit.submit(
        visitId: 'visit-1',
        changes: changes,
        countryDateExpansion: cubit.state.pendingExpansion,
      );

      expect(changes, {'country_visit_id': expansion.countryVisitId});

      expect(changes.containsKey('country_date_expansion'), isFalse);

      await cubit.close();
    });
  });
}
