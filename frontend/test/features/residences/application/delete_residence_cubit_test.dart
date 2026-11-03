import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/residences/application/delete_residence_cubit.dart';
import 'package:beenaround/features/residences/application/delete_residence_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_residence_repository.dart';

class FakeResidenceDeletionRepository extends FakeResidenceRepository {
  int deleteCalls = 0;

  String? receivedResidenceId;

  Future<void> Function()? deleteHandler;

  @override
  Future<void> deleteResidence({required String residenceId}) async {
    deleteCalls++;
    receivedResidenceId = residenceId;

    if (deleteHandler != null) {
      await deleteHandler!();
    }
  }
}

void main() {
  group('DeleteResidenceCubit', () {
    test('starts idle', () async {
      final cubit = DeleteResidenceCubit(
        repository: FakeResidenceDeletionRepository(),
      );

      addTearDown(cubit.close);

      expect(cubit.state.phase, DeleteResidencePhase.idle);
      expect(cubit.state.deletedResidenceId, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('deletes a residence successfully', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(residenceId: 'residence-1');

      expect(success, isTrue);

      expect(repository.deleteCalls, 1);
      expect(repository.receivedResidenceId, 'residence-1');

      expect(cubit.state.phase, DeleteResidencePhase.success);
      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.wasDeleted, isTrue);

      expect(cubit.state.deletedResidenceId, 'residence-1');
      expect(cubit.state.errorMessage, isNull);
    });

    test('rejects an empty residence ID', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(residenceId: '   ');

      expect(success, isFalse);

      expect(repository.deleteCalls, 0);

      expect(cubit.state.phase, DeleteResidencePhase.failure);
      expect(cubit.state.errorMessage, 'Invalid residence identifier.');
    });

    test('normalizes surrounding whitespace in the ID', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(
        residenceId: '  residence-1  ',
      );

      expect(success, isTrue);
      expect(repository.receivedResidenceId, 'residence-1');
      expect(cubit.state.deletedResidenceId, 'residence-1');
    });

    test('exposes deleting state while request is pending', () async {
      final completer = Completer<void>();

      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () => completer.future;

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final deleting = cubit.deleteResidence(residenceId: 'residence-1');

      expect(cubit.state.phase, DeleteResidencePhase.deleting);
      expect(cubit.state.isDeleting, isTrue);

      completer.complete();

      expect(await deleting, isTrue);

      expect(cubit.state.phase, DeleteResidencePhase.success);
    });

    test('prevents duplicate deletions while pending', () async {
      final completer = Completer<void>();

      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () => completer.future;

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final first = cubit.deleteResidence(residenceId: 'residence-1');

      final second = await cubit.deleteResidence(residenceId: 'residence-1');

      expect(second, isFalse);
      expect(repository.deleteCalls, 1);

      completer.complete();

      expect(await first, isTrue);
    });

    test('does not repeat deletion after success', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isTrue);

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isFalse);

      expect(repository.deleteCalls, 1);
    });

    test('maps HTTP 404 to a failure state', () async {
      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () async {
          throw const ApiException(
            type: ApiErrorType.notFound,
            message: 'The requested resource was not found.',
            statusCode: 404,
          );
        };

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(residenceId: 'residence-1');

      expect(success, isFalse);

      expect(cubit.state.phase, DeleteResidencePhase.failure);
      expect(cubit.state.wasDeleted, isFalse);
      expect(cubit.state.deletedResidenceId, isNull);

      expect(cubit.state.errorMessage, 'The requested resource was not found.');
    });

    test('maps connection failures', () async {
      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () async {
          throw const ApiException(
            type: ApiErrorType.connection,
            message: 'Unable to connect to the server.',
          );
        };

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(residenceId: 'residence-1');

      expect(success, isFalse);

      expect(cubit.state.phase, DeleteResidencePhase.failure);

      expect(cubit.state.errorMessage, 'Unable to connect to the server.');
    });

    test('handles unexpected errors', () async {
      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () async {
          throw StateError('Unexpected error');
        };

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.deleteResidence(residenceId: 'residence-1');

      expect(success, isFalse);

      expect(cubit.state.phase, DeleteResidencePhase.failure);

      expect(
        cubit.state.errorMessage,
        'Unable to delete your residence. Please try again.',
      );
    });

    test('allows retry after a failure', () async {
      final repository = FakeResidenceDeletionRepository();

      repository.deleteHandler = () async {
        if (repository.deleteCalls == 1) {
          throw StateError('Temporary failure');
        }
      };

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isFalse);

      expect(cubit.state.phase, DeleteResidencePhase.failure);

      cubit.clearError();

      expect(cubit.state.phase, DeleteResidencePhase.idle);

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isTrue);

      expect(repository.deleteCalls, 2);
    });

    test('reset permits another explicit deletion', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      addTearDown(cubit.close);

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isTrue);

      cubit.reset();

      expect(cubit.state.phase, DeleteResidencePhase.idle);
      expect(cubit.state.deletedResidenceId, isNull);

      expect(await cubit.deleteResidence(residenceId: 'residence-2'), isTrue);

      expect(repository.deleteCalls, 2);
      expect(repository.receivedResidenceId, 'residence-2');
    });

    test('does not emit after being closed during deletion', () async {
      final completer = Completer<void>();

      final repository = FakeResidenceDeletionRepository()
        ..deleteHandler = () => completer.future;

      final cubit = DeleteResidenceCubit(repository: repository);

      final deleting = cubit.deleteResidence(residenceId: 'residence-1');

      await cubit.close();

      completer.complete();

      expect(await deleting, isFalse);
      expect(cubit.isClosed, isTrue);
    });

    test('ignores deletion requests after close', () async {
      final repository = FakeResidenceDeletionRepository();

      final cubit = DeleteResidenceCubit(repository: repository);

      await cubit.close();

      expect(await cubit.deleteResidence(residenceId: 'residence-1'), isFalse);

      expect(repository.deleteCalls, 0);
    });
  });
}
