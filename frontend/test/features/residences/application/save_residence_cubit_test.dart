import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/residences/application/save_residence_cubit.dart';
import 'package:beenaround/features/residences/application/save_residence_state.dart';

import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';

import 'package:flutter_test/flutter_test.dart';

import 'fake_residence_repository.dart';

class FakeResidenceWritesRepository extends FakeResidenceRepository {
  int createCalls = 0;
  int updateCalls = 0;

  ResidenceInput? receivedInput;
  String? receivedResidenceId;
  ResidenceChanges? receivedChanges;

  ResidenceOverlapProposal? receivedConfirmation;

  Future<Residence> Function()? createHandler;
  Future<Residence> Function()? updateHandler;

  @override
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  }) async {
    createCalls++;

    receivedInput = input;
    receivedConfirmation = overlapConfirmation;

    if (createHandler != null) {
      return createHandler!();
    }

    return sampleResidence();
  }

  @override
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  }) async {
    updateCalls++;

    receivedResidenceId = residenceId;
    receivedChanges = changes;
    receivedConfirmation = overlapConfirmation;

    if (updateHandler != null) {
      return updateHandler!();
    }

    return sampleResidence();
  }
}

Residence sampleResidence() {
  return Residence(
    id: 'residence-1',
    countryCode: 'PT',
    cityId: null,
    startedOn: DateTime(2020, 3),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2023, 8),
    endedOnPrecision: VisitDatePrecision.month,
    note: 'Studied here.',
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );
}

ResidenceInput sampleInput({String countryCode = 'PT'}) {
  return ResidenceInput(
    countryCode: countryCode,
    startedOn: DateTime(2020, 3),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2023, 8),
    endedOnPrecision: VisitDatePrecision.month,
    note: 'Studied here.',
  );
}

ResidenceOverlapProposal sampleProposal({bool includeTarget = false}) {
  final location = {
    'country_code': 'PT',
    'city_id': null,
    'started_on': '2020-03-01',
    'started_on_precision': 'month',
    'ended_on': '2023-08-01',
    'ended_on_precision': 'month',
  };

  return ResidenceOverlapProposal.fromJson({
    'code': 'RESIDENCE_PERIOD_OVERLAP',
    'message': 'Residence overlaps with existing periods.',
    'requested': location,
    'overlaps': [
      {
        'residence_id': 'residence-2',
        'kind': 'certain',
        'country_code': 'ES',
        'city_id': null,
        'started_on': '2022-01-01',
        'started_on_precision': 'month',
        'ended_on': '2022-12-01',
        'ended_on_precision': 'month',
      },
    ],
    'expected_target': includeTarget
        ? {...location, 'residence_id': 'residence-1'}
        : null,
  });
}

void main() {
  group('SaveResidenceCubit - creation', () {
    test('starts idle', () async {
      final cubit = SaveResidenceCubit(
        repository: FakeResidenceWritesRepository(),
      );

      expect(cubit.state.phase, SaveResidencePhase.idle);

      await cubit.close();
    });

    test('creates a residence successfully', () async {
      final repository = FakeResidenceWritesRepository();

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final input = sampleInput();

      final success = await cubit.create(input: input);

      expect(success, isTrue);

      expect(repository.createCalls, 1);
      expect(repository.receivedInput, same(input));
      expect(repository.receivedConfirmation, isNull);

      expect(cubit.state.phase, SaveResidencePhase.success);
      expect(cubit.state.savedResidence?.id, 'residence-1');
    });

    test('prevents duplicate submissions while saving', () async {
      final completer = Completer<Residence>();

      final repository = FakeResidenceWritesRepository()
        ..createHandler = () => completer.future;

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final first = cubit.create(input: sampleInput());

      expect(cubit.state.phase, SaveResidencePhase.submitting);

      final second = await cubit.create(input: sampleInput());

      expect(second, isFalse);
      expect(repository.createCalls, 1);

      completer.complete(sampleResidence());

      expect(await first, isTrue);
    });

    test('does not automatically retry an overlap', () async {
      final proposal = sampleProposal();

      final repository = FakeResidenceWritesRepository()
        ..createHandler = () async {
          throw ResidenceOverlapRequired(proposal);
        };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.create(input: sampleInput());

      expect(success, isFalse);

      expect(repository.createCalls, 1);
      expect(cubit.state.phase, SaveResidencePhase.overlapRequired);

      expect(cubit.state.pendingProposal, same(proposal));
      expect(cubit.state.requiresConfirmation, isTrue);

      // No second request is made before explicit approval.
      expect(repository.createCalls, 1);
    });

    test('explicit confirmation reuses the original input', () async {
      final proposal = sampleProposal();

      final repository = FakeResidenceWritesRepository();

      repository.createHandler = () async {
        if (repository.createCalls == 1) {
          throw ResidenceOverlapRequired(proposal);
        }

        return sampleResidence();
      };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final originalInput = sampleInput();

      expect(await cubit.create(input: originalInput), isFalse);

      expect(cubit.state.requiresConfirmation, isTrue);

      final success = await cubit.confirmOverlap();

      expect(success, isTrue);

      expect(repository.createCalls, 2);

      expect(repository.receivedInput, same(originalInput));

      expect(repository.receivedConfirmation, same(proposal));

      expect(cubit.state.phase, SaveResidencePhase.success);
      expect(cubit.state.pendingSave, isNull);
    });

    test('dismisses an overlap without saving', () async {
      final repository = FakeResidenceWritesRepository()
        ..createHandler = () async {
          throw ResidenceOverlapRequired(sampleProposal());
        };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.create(input: sampleInput());

      expect(cubit.state.requiresConfirmation, isTrue);

      cubit.dismissOverlap();

      expect(cubit.state.phase, SaveResidencePhase.idle);
      expect(cubit.state.pendingSave, isNull);
      expect(repository.createCalls, 1);

      expect(await cubit.confirmOverlap(), isFalse);
      expect(repository.createCalls, 1);
    });

    test('a new submission discards the previous proposal', () async {
      final proposal = sampleProposal();

      final repository = FakeResidenceWritesRepository();

      repository.createHandler = () async {
        if (repository.createCalls == 1) {
          throw ResidenceOverlapRequired(proposal);
        }

        return sampleResidence();
      };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.create(input: sampleInput());

      expect(cubit.state.requiresConfirmation, isTrue);

      // The user changed the destination and submitted again.
      final newInput = sampleInput(countryCode: 'ES');

      final success = await cubit.create(input: newInput);

      expect(success, isTrue);

      expect(repository.receivedInput, same(newInput));
      expect(repository.receivedConfirmation, isNull);

      expect(cubit.state.pendingSave, isNull);
      expect(cubit.state.phase, SaveResidencePhase.success);
    });
    test('clears pending confirmation after a failed retry', () async {
      final proposal = sampleProposal();

      final repository = FakeResidenceWritesRepository();

      repository.createHandler = () async {
        if (repository.createCalls == 1) {
          throw ResidenceOverlapRequired(proposal);
        }

        throw StateError('Unexpected failure');
      };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.create(input: sampleInput());

      expect(cubit.state.requiresConfirmation, isTrue);

      final success = await cubit.confirmOverlap();

      expect(success, isFalse);

      expect(cubit.state.phase, SaveResidencePhase.failure);
      expect(cubit.state.pendingSave, isNull);
      expect(cubit.state.requiresConfirmation, isFalse);
    });
  });
  group('SaveResidenceCubit - updates', () {
    test('updates a residence note', () async {
      final repository = FakeResidenceWritesRepository();

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final changes = ResidenceChanges(
        note: 'My first apartment.',
        updateNote: true,
      );

      final success = await cubit.update(
        residenceId: 'residence-1',
        changes: changes,
      );

      expect(success, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.receivedResidenceId, 'residence-1');
      expect(repository.receivedChanges, same(changes));
      expect(repository.receivedConfirmation, isNull);

      expect(cubit.state.phase, SaveResidencePhase.success);
    });

    test('confirms an update overlap explicitly', () async {
      final proposal = sampleProposal(includeTarget: true);

      final repository = FakeResidenceWritesRepository();

      repository.updateHandler = () async {
        if (repository.updateCalls == 1) {
          throw ResidenceOverlapRequired(proposal);
        }

        return sampleResidence();
      };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final changes = ResidenceChanges(
        endedOn: DateTime(2024, 6),
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(
        await cubit.update(residenceId: 'residence-1', changes: changes),
        isFalse,
      );

      expect(cubit.state.requiresConfirmation, isTrue);
      expect(cubit.state.pendingSave?.isUpdate, isTrue);

      final success = await cubit.confirmOverlap();

      expect(success, isTrue);

      expect(repository.updateCalls, 2);
      expect(repository.receivedResidenceId, 'residence-1');
      expect(repository.receivedChanges, same(changes));
      expect(repository.receivedConfirmation, same(proposal));
    });

    test('discards stale overlap confirmations', () async {
      final proposal = sampleProposal();

      final repository = FakeResidenceWritesRepository();

      repository.createHandler = () async {
        if (repository.createCalls == 1) {
          throw ResidenceOverlapRequired(proposal);
        }

        throw const ResidenceOverlapStale(
          'The overlapping residences have changed.',
        );
      };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.create(input: sampleInput());

      expect(cubit.state.requiresConfirmation, isTrue);

      final success = await cubit.confirmOverlap();

      expect(success, isFalse);

      expect(cubit.state.phase, SaveResidencePhase.stale);
      expect(cubit.state.pendingSave, isNull);

      expect(
        cubit.state.errorMessage,
        'The overlapping residences have changed.',
      );

      // The stale confirmation must never be submitted again.
      expect(await cubit.confirmOverlap(), isFalse);
      expect(repository.createCalls, 2);
    });

    test('maps API failures to an error state', () async {
      final repository = FakeResidenceWritesRepository()
        ..createHandler = () async {
          throw const ApiException(
            type: ApiErrorType.connection,
            message: 'Unable to connect to the server.',
          );
        };

      final cubit = SaveResidenceCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.create(input: sampleInput());

      expect(success, isFalse);
      expect(cubit.state.phase, SaveResidencePhase.failure);

      expect(cubit.state.errorMessage, 'Unable to connect to the server.');
    });

    test('does not emit after being closed during submission', () async {
      final completer = Completer<Residence>();

      final repository = FakeResidenceWritesRepository()
        ..createHandler = () => completer.future;

      final cubit = SaveResidenceCubit(repository: repository);

      final saving = cubit.create(input: sampleInput());

      await cubit.close();

      completer.complete(sampleResidence());

      expect(await saving, isFalse);
      expect(cubit.isClosed, isTrue);
    });
  });
}
