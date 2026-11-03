import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/residences/application/residences_cubit.dart';
import 'package:beenaround/features/residences/application/residences_state.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_residence_repository.dart';

Residence makeResidence({
  required String id,
  String countryCode = 'PT',
  int? cityId,
}) {
  return Residence(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    startedOn: DateTime(2020, 3),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2023, 8),
    endedOnPrecision: VisitDatePrecision.month,
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );
}

void main() {
  group('ResidencesCubit', () {
    test('starts with an initial state', () async {
      final cubit = ResidencesCubit(repository: FakeResidenceRepository());

      expect(cubit.state.phase, ResidencesPhase.initial);
      expect(cubit.state.residences, isEmpty);

      await cubit.close();
    });

    test('loads residence history', () async {
      final repository = FakeResidenceRepository()
        ..residences = [
          makeResidence(id: '1'),
          makeResidence(id: '2', cityId: 2267057),
        ];

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.loadCalls, 1);
      expect(cubit.state.phase, ResidencesPhase.ready);
      expect(cubit.state.totalResidences, 2);
      expect(cubit.state.livedCountryCount, 1);
      expect(cubit.state.livedCityCount, 1);
    });

    test('counts multiple residence periods independently', () async {
      final repository = FakeResidenceRepository()
        ..residences = [
          makeResidence(id: '1', cityId: 2267057),
          makeResidence(id: '2', cityId: 2267057),
          makeResidence(id: '3', cityId: 2735941),
        ];

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.totalResidences, 3);
      expect(cubit.state.livedCountryCount, 1);
      expect(cubit.state.livedCityCount, 2);

      expect(cubit.state.residencesForCountry('PT'), hasLength(3));

      expect(cubit.state.residencesForCity(2267057), hasLength(2));
    });

    test('distinguishes direct country and city residences', () async {
      final repository = FakeResidenceRepository()
        ..residences = [
          makeResidence(id: 'country'),
          makeResidence(id: 'city', cityId: 2267057),
        ];

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.residencesForCountry('PT'), hasLength(2));

      expect(cubit.state.directCountryResidences('PT'), hasLength(1));
    });

    test('exposes loading state while pending', () async {
      final completer = Completer<List<Residence>>();

      final repository = FakeResidenceRepository()
        ..loadHandler = () => completer.future;

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      final loading = cubit.load();

      expect(cubit.state.phase, ResidencesPhase.loading);

      completer.complete([makeResidence(id: '1')]);

      await loading;

      expect(cubit.state.phase, ResidencesPhase.ready);
      expect(cubit.state.totalResidences, 1);
    });

    test('preserves existing data when refresh fails', () async {
      final repository = FakeResidenceRepository()
        ..residences = [makeResidence(id: '1')];

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      repository.error = StateError('Network unavailable');

      await cubit.refresh();

      expect(cubit.state.phase, ResidencesPhase.failure);
      expect(cubit.state.totalResidences, 1);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('ignores outdated load responses', () async {
      final first = Completer<List<Residence>>();
      final second = Completer<List<Residence>>();

      var calls = 0;

      final repository = FakeResidenceRepository()
        ..loadHandler = () {
          calls++;

          return calls == 1 ? first.future : second.future;
        };

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      final firstLoad = cubit.load();
      final secondLoad = cubit.load();

      second.complete([makeResidence(id: 'new')]);

      await secondLoad;

      expect(cubit.state.residences.single.id, 'new');

      first.complete([makeResidence(id: 'old')]);

      await firstLoad;

      expect(cubit.state.residences.single.id, 'new');
    });

    test('does not emit after close', () async {
      final completer = Completer<List<Residence>>();

      final repository = FakeResidenceRepository()
        ..loadHandler = () => completer.future;

      final cubit = ResidencesCubit(repository: repository);

      final loading = cubit.load();

      await cubit.close();

      completer.complete([makeResidence(id: '1')]);

      await loading;

      expect(cubit.isClosed, isTrue);
    });

    test('exposes immutable residence lists', () async {
      final repository = FakeResidenceRepository()
        ..residences = [makeResidence(id: '1')];

      final cubit = ResidencesCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(() => cubit.state.residences.clear(), throwsUnsupportedError);

      expect(
        () => cubit.state.residencesForCountry('PT').clear(),
        throwsUnsupportedError,
      );
    });
  });
}
