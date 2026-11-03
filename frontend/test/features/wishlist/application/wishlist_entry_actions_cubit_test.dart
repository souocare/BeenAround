import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/wishlist/application/wishlist_entry_actions_cubit.dart';
import 'package:beenaround/features/wishlist/application/wishlist_entry_actions_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wishlist_repository.dart';

class FakeWishlistActionsRepository extends FakeWishlistRepository {
  int updateCalls = 0;
  int deleteCalls = 0;

  String? receivedUpdateId;
  String? receivedNote;
  String? receivedDeleteId;

  Future<WishlistEntry> Function()? updateHandler;
  Future<void> Function()? deleteHandler;

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) async {
    updateCalls++;
    receivedUpdateId = entryId;
    receivedNote = note;

    if (updateHandler != null) {
      return updateHandler!();
    }

    return makeEntry(note: note);
  }

  @override
  Future<void> deleteWishlistEntry({required String entryId}) async {
    deleteCalls++;
    receivedDeleteId = entryId;

    if (deleteHandler != null) {
      await deleteHandler!();
    }
  }
}

WishlistEntry makeEntry({String id = 'wishlist-1', String? note}) {
  return WishlistEntry(
    id: id,
    countryCode: 'PT',
    cityId: null,
    note: note,
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );
}

void main() {
  group('WishlistEntryActionsCubit - update note', () {
    test('starts idle', () async {
      final cubit = WishlistEntryActionsCubit(
        repository: FakeWishlistActionsRepository(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.phase, WishlistEntryActionPhase.idle);
    });

    test('updates a note successfully', () async {
      final repository = FakeWishlistActionsRepository();
      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.updateNote(
        entryId: 'wishlist-1',
        note: 'Visit the Azores.',
      );

      expect(success, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.receivedUpdateId, 'wishlist-1');
      expect(repository.receivedNote, 'Visit the Azores.');

      expect(cubit.state.phase, WishlistEntryActionPhase.success);
      expect(cubit.state.noteUpdated, isTrue);
      expect(cubit.state.updatedEntry?.note, 'Visit the Azores.');
      expect(cubit.state.deletedEntryId, isNull);
    });

    test('clears a note using explicit null', () async {
      final repository = FakeWishlistActionsRepository();
      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.updateNote(entryId: 'wishlist-1', note: null);

      expect(success, isTrue);
      expect(repository.receivedNote, isNull);
      expect(cubit.state.noteUpdated, isTrue);
      expect(cubit.state.updatedEntry?.note, isNull);
    });

    test('prevents duplicate submissions', () async {
      final completer = Completer<WishlistEntry>();

      final repository = FakeWishlistActionsRepository()
        ..updateHandler = () => completer.future;

      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final first = cubit.updateNote(entryId: 'wishlist-1', note: 'Updated.');

      expect(cubit.state.isSubmitting, isTrue);

      final second = await cubit.updateNote(
        entryId: 'wishlist-1',
        note: 'Another update.',
      );

      expect(second, isFalse);
      expect(repository.updateCalls, 1);

      completer.complete(makeEntry(note: 'Updated.'));

      expect(await first, isTrue);
    });

    test('maps API errors', () async {
      final repository = FakeWishlistActionsRepository()
        ..updateHandler = () async {
          throw const ApiException(
            type: ApiErrorType.connection,
            message: 'Unable to connect to the server.',
          );
        };

      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.updateNote(
        entryId: 'wishlist-1',
        note: 'Updated.',
      );

      expect(success, isFalse);
      expect(cubit.state.phase, WishlistEntryActionPhase.failure);
      expect(cubit.state.errorMessage, 'Unable to connect to the server.');
    });

    test('allows retrying after an error', () async {
      final repository = FakeWishlistActionsRepository();

      repository.updateHandler = () async {
        if (repository.updateCalls == 1) {
          throw StateError('Temporary failure');
        }

        return makeEntry(note: 'Updated.');
      };

      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      expect(
        await cubit.updateNote(entryId: 'wishlist-1', note: 'Updated.'),
        isFalse,
      );

      cubit.clearError();

      expect(cubit.state.phase, WishlistEntryActionPhase.idle);

      expect(
        await cubit.updateNote(entryId: 'wishlist-1', note: 'Updated.'),
        isTrue,
      );

      expect(repository.updateCalls, 2);
    });

    test('does not emit after close', () async {
      final completer = Completer<WishlistEntry>();

      final repository = FakeWishlistActionsRepository()
        ..updateHandler = () => completer.future;

      final cubit = WishlistEntryActionsCubit(repository: repository);

      final saving = cubit.updateNote(entryId: 'wishlist-1', note: 'Updated.');

      await cubit.close();

      completer.complete(makeEntry(note: 'Updated.'));

      expect(await saving, isFalse);
      expect(cubit.isClosed, isTrue);
    });
  });

  group('WishlistEntryActionsCubit - deletion', () {
    test('deletes a wishlist entry', () async {
      final repository = FakeWishlistActionsRepository();
      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.deleteEntry(entryId: 'wishlist-1');

      expect(success, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.receivedDeleteId, 'wishlist-1');

      expect(cubit.state.phase, WishlistEntryActionPhase.success);
      expect(cubit.state.entryDeleted, isTrue);
      expect(cubit.state.deletedEntryId, 'wishlist-1');
      expect(cubit.state.updatedEntry, isNull);
    });

    test('does not call delete twice while pending', () async {
      final completer = Completer<void>();

      final repository = FakeWishlistActionsRepository()
        ..deleteHandler = () => completer.future;

      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final first = cubit.deleteEntry(entryId: 'wishlist-1');

      expect(cubit.state.isSubmitting, isTrue);

      final second = await cubit.deleteEntry(entryId: 'wishlist-1');

      expect(second, isFalse);
      expect(repository.deleteCalls, 1);

      completer.complete();

      expect(await first, isTrue);
    });

    test('does not repeat deletion after success', () async {
      final repository = FakeWishlistActionsRepository();
      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      expect(await cubit.deleteEntry(entryId: 'wishlist-1'), isTrue);

      expect(await cubit.deleteEntry(entryId: 'wishlist-1'), isFalse);

      expect(repository.deleteCalls, 1);
    });

    test('maps HTTP 404 when entry is unavailable', () async {
      final repository = FakeWishlistActionsRepository()
        ..deleteHandler = () async {
          throw const ApiException(
            type: ApiErrorType.notFound,
            message: 'The requested resource was not found.',
            statusCode: 404,
          );
        };

      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      final success = await cubit.deleteEntry(entryId: 'wishlist-1');

      expect(success, isFalse);
      expect(cubit.state.phase, WishlistEntryActionPhase.failure);
      expect(cubit.state.entryDeleted, isFalse);
      expect(cubit.state.deletedEntryId, isNull);
    });

    test('reset allows another explicit operation', () async {
      final repository = FakeWishlistActionsRepository();
      final cubit = WishlistEntryActionsCubit(repository: repository);
      addTearDown(cubit.close);

      expect(await cubit.deleteEntry(entryId: 'wishlist-1'), isTrue);

      cubit.reset();

      expect(cubit.state.phase, WishlistEntryActionPhase.idle);

      expect(
        await cubit.updateNote(entryId: 'wishlist-2', note: 'Updated.'),
        isTrue,
      );

      expect(repository.deleteCalls, 1);
      expect(repository.updateCalls, 1);
    });

    test('does not emit after close during deletion', () async {
      final completer = Completer<void>();

      final repository = FakeWishlistActionsRepository()
        ..deleteHandler = () => completer.future;

      final cubit = WishlistEntryActionsCubit(repository: repository);

      final deleting = cubit.deleteEntry(entryId: 'wishlist-1');

      await cubit.close();

      completer.complete();

      expect(await deleting, isFalse);
      expect(cubit.isClosed, isTrue);
    });
  });
}
