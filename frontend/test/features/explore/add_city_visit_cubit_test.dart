import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/add_city_visit_cubit.dart';
import 'package:beenaround/features/explore/application/add_city_visit_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int createCalls = 0;

  int? receivedCityId;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;
  VisitDatePrecision? receivedStartedOnPrecision;
  VisitDatePrecision? receivedEndedOnPrecision;

  Future<CityVisit> Function()? createHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) {
    createCalls++;

    receivedCityId = cityId;
    receivedStartedOn = startedOn;
    receivedEndedOn = endedOn;
    receivedStartedOnPrecision = startedOnPrecision;
    receivedEndedOnPrecision = endedOnPrecision;

    if (createHandler != null) {
      return createHandler!();
    }

    return Future.value(
      CityVisit(
        id: 'visit-1',
        cityId: cityId,
        cityName: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        startedOn: startedOn,
        endedOn: endedOn,
        startedOnPrecision: startedOnPrecision,
        endedOnPrecision: endedOnPrecision,
        createdAt: DateTime(2026, 10, 24),
        updatedAt: DateTime(2026, 10, 24),
      ),
    );
  }
}

void main() {
  group('AddCityVisitCubit', () {
    test('starts idle', () async {
      final cubit = AddCityVisitCubit(repository: FakeCityVisitsRepository());

      expect(cubit.state.phase, AddCityVisitPhase.idle);

      await cubit.close();
    });

    test('rejects a visit without dates', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(cityId: 2267057);

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.phase, AddCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('creates a visit with exact dates', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedCityId, 2267057);
      expect(repository.receivedStartedOn, start);
      expect(repository.receivedEndedOn, end);

      expect(repository.receivedStartedOnPrecision, VisitDatePrecision.day);

      expect(repository.receivedEndedOnPrecision, VisitDatePrecision.day);

      expect(cubit.state.phase, AddCityVisitPhase.success);

      await cubit.close();
    });

    test('rejects a missing end date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: DateTime(2020, 5, 12),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('rejects an invalid city ID', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(cityId: 0);

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.phase, AddCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Please select a city.');

      await cubit.close();
    });

    test('rejects a missing start date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(cubit.state.errorMessage, 'Start and end dates are required.');

      await cubit.close();
    });

    test('rejects an end date earlier than the start date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
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
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: DateTime(2026, 10, 15, 23),
        endedOn: DateTime(2026, 10, 15, 8),
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);

      await cubit.close();
    });

    test('prevents duplicate submissions', () async {
      final repository = FakeCityVisitsRepository();
      final pending = Completer<CityVisit>();

      repository.createHandler = () => pending.future;

      final cubit = AddCityVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final first = cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      final second = await cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      expect(second, isFalse);
      expect(repository.createCalls, 1);

      pending.complete(
        CityVisit(
          id: 'visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          startedOn: start,
          endedOn: end,
          startedOnPrecision: VisitDatePrecision.day,
          endedOnPrecision: VisitDatePrecision.day,
          createdAt: DateTime(2026, 10, 24),
          updatedAt: DateTime(2026, 10, 24),
        ),
      );

      expect(await first, isTrue);
      expect(cubit.state.phase, AddCityVisitPhase.success);

      await cubit.close();
    });

    test('maps API errors to failure state', () async {
      final repository = FakeCityVisitsRepository();

      repository.createHandler = () async {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Server unavailable.',
        );
      };

      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      );

      expect(success, isFalse);
      expect(repository.createCalls, 1);
      expect(cubit.state.phase, AddCityVisitPhase.failure);
      expect(cubit.state.errorMessage, 'Server unavailable.');

      await cubit.close();
    });

    test('can retry after failure', () async {
      final repository = FakeCityVisitsRepository();

      repository.createHandler = () async {
        throw const FormatException('Invalid response');
      };

      final cubit = AddCityVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final first = await cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      expect(first, isFalse);
      expect(repository.createCalls, 1);
      expect(cubit.state.phase, AddCityVisitPhase.failure);

      repository.createHandler = null;

      cubit.clearError();

      expect(cubit.state.phase, AddCityVisitPhase.idle);

      final second = await cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      expect(second, isTrue);
      expect(repository.createCalls, 2);
      expect(cubit.state.phase, AddCityVisitPhase.success);

      await cubit.close();
    });

    test('ignores responses after close', () async {
      final repository = FakeCityVisitsRepository();
      final pending = Completer<CityVisit>();

      repository.createHandler = () => pending.future;

      final cubit = AddCityVisitCubit(repository: repository);

      final start = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 15);

      final submission = cubit.submit(
        cityId: 2267057,
        startedOn: start,
        endedOn: end,
      );

      await cubit.close();

      pending.complete(
        CityVisit(
          id: 'visit-1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
          startedOn: start,
          endedOn: end,
          startedOnPrecision: VisitDatePrecision.day,
          endedOnPrecision: VisitDatePrecision.day,
          createdAt: DateTime(2026, 10, 24),
          updatedAt: DateTime(2026, 10, 24),
        ),
      );

      expect(await submission, isFalse);
    });

    test('creates a city visit with month precision', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
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

    test('creates a city visit with year precision', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2025, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.year,
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedStartedOnPrecision, VisitDatePrecision.year);
      expect(repository.receivedEndedOnPrecision, VisitDatePrecision.year);

      await cubit.close();
    });

    test('creates a visit with mixed precisions', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 6, 15),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.day,
      );

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.receivedStartedOnPrecision, VisitDatePrecision.year);
      expect(repository.receivedEndedOnPrecision, VisitDatePrecision.day);

      await cubit.close();
    });

    test('rejects precision without a date', () async {
      final repository = FakeCityVisitsRepository();
      final cubit = AddCityVisitCubit(repository: repository);

      final success = await cubit.submit(
        cityId: 2267057,
        endedOnPrecision: VisitDatePrecision.year,
      );

      expect(success, isFalse);
      expect(repository.createCalls, 0);
      expect(
        cubit.state.errorMessage,
        'An end date precision requires an end date.',
      );

      await cubit.close();
    });
  });
}
