import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/wishlist/application/add_wishlist_entry_cubit.dart';
import 'package:beenaround/features/wishlist/application/add_wishlist_entry_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wishlist_repository.dart';

class FakeWishlistWritesRepository extends FakeWishlistRepository {
  int addCalls = 0;

  WishlistEntryInput? receivedInput;

  Future<WishlistCreationResult> Function()? addHandler;

  @override
  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  }) async {
    addCalls++;
    receivedInput = input;

    if (addHandler != null) {
      return addHandler!();
    }

    return WishlistCreationResult(created: [sampleEntry()], existing: const []);
  }
}

WishlistEntry sampleEntry({
  String id = 'wishlist-1',
  String? countryCode = 'PT',
  int? cityId,
  String? note,
}) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    note: note,
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );
}

WishlistCreationResult createdResult() {
  return WishlistCreationResult(created: [sampleEntry()], existing: const []);
}

WishlistCreationResult existingResult() {
  return WishlistCreationResult(
    created: const [],
    existing: [sampleEntry(note: 'Original note.')],
  );
}

WishlistCreationResult partialResult() {
  return WishlistCreationResult(
    created: [
      sampleEntry(
        id: 'city-entry',
        countryCode: null,
        cityId: 2267057,
        note: 'Explore Alfama.',
      ),
    ],
    existing: [
      sampleEntry(
        id: 'country-entry',
        countryCode: 'PT',
        note: 'Visit the Douro.',
      ),
    ],
  );
}

void main() {
  group('AddWishlistEntryCubit', () {
    test('starts idle', () async {
      final cubit = AddWishlistEntryCubit(
        repository: FakeWishlistWritesRepository(),
      );

      expect(cubit.state.phase, AddWishlistEntryPhase.idle);
      expect(cubit.state.result, isNull);

      await cubit.close();
    });

    test('adds a country successfully', () async {
      final repository = FakeWishlistWritesRepository();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final input = WishlistEntryInput.country(
        countryCode: 'PT',
        note: 'Visit the Azores.',
      );

      final success = await cubit.submit(input: input);

      expect(success, isTrue);
      expect(repository.addCalls, 1);
      expect(repository.receivedInput, same(input));

      expect(cubit.state.phase, AddWishlistEntryPhase.success);
      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.hasCreatedEntries, isTrue);

      expect(cubit.state.createdCount, 1);
      expect(cubit.state.existingCount, 0);
    });

    test('preserves city input and includeCountry selection', () async {
      final repository = FakeWishlistWritesRepository();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final input = WishlistEntryInput.city(
        cityId: 2267057,
        includeCountry: true,
        note: 'Explore Alfama.',
      );

      final success = await cubit.submit(input: input);

      expect(success, isTrue);
      expect(repository.addCalls, 1);

      final received = repository.receivedInput!;

      expect(received.cityId, 2267057);
      expect(received.includeCountry, isTrue);
      expect(received.note, 'Explore Alfama.');
    });

    test('accepts a destination that already exists', () async {
      final repository = FakeWishlistWritesRepository()
        ..addHandler = () async => existingResult();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.submit(
        input: WishlistEntryInput.country(
          countryCode: 'PT',
          note: 'Different note.',
        ),
      );

      expect(success, isTrue);

      expect(cubit.state.phase, AddWishlistEntryPhase.success);
      expect(cubit.state.allAlreadyExisted, isTrue);

      expect(cubit.state.createdCount, 0);
      expect(cubit.state.existingCount, 1);

      expect(cubit.state.result!.existing.single.note, 'Original note.');
    });

    test('preserves partially created results', () async {
      final repository = FakeWishlistWritesRepository()
        ..addHandler = () async => partialResult();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.submit(
        input: WishlistEntryInput.city(
          cityId: 2267057,
          includeCountry: true,
          note: 'Explore Alfama.',
        ),
      );

      expect(success, isTrue);

      expect(cubit.state.partiallyCreated, isTrue);
      expect(cubit.state.createdCount, 1);
      expect(cubit.state.existingCount, 1);

      final result = cubit.state.result!;

      expect(result.created.single.cityId, 2267057);

      expect(result.created.single.note, 'Explore Alfama.');

      expect(result.existing.single.countryCode, 'PT');

      expect(result.existing.single.note, 'Visit the Douro.');
    });

    test('exposes submitting state while request is pending', () async {
      final completer = Completer<WishlistCreationResult>();

      final repository = FakeWishlistWritesRepository()
        ..addHandler = () => completer.future;

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final saving = cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      expect(cubit.state.phase, AddWishlistEntryPhase.submitting);

      completer.complete(createdResult());

      expect(await saving, isTrue);

      expect(cubit.state.phase, AddWishlistEntryPhase.success);
    });

    test('prevents duplicate submissions while saving', () async {
      final completer = Completer<WishlistCreationResult>();

      final repository = FakeWishlistWritesRepository()
        ..addHandler = () => completer.future;

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final first = cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      final second = await cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      expect(second, isFalse);
      expect(repository.addCalls, 1);

      completer.complete(createdResult());

      expect(await first, isTrue);
    });

    test('prevents repeated submissions after success', () async {
      final repository = FakeWishlistWritesRepository();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final input = WishlistEntryInput.country(countryCode: 'PT');

      expect(await cubit.submit(input: input), isTrue);

      expect(await cubit.submit(input: input), isFalse);

      expect(repository.addCalls, 1);
    });

    test('reset permits a new explicit submission', () async {
      final repository = FakeWishlistWritesRepository();

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final input = WishlistEntryInput.country(countryCode: 'PT');

      expect(await cubit.submit(input: input), isTrue);

      cubit.reset();

      expect(cubit.state.phase, AddWishlistEntryPhase.idle);
      expect(cubit.state.result, isNull);

      expect(await cubit.submit(input: input), isTrue);

      expect(repository.addCalls, 2);
    });

    test('maps API failures to user-friendly messages', () async {
      final repository = FakeWishlistWritesRepository()
        ..addHandler = () async {
          throw const ApiException(
            type: ApiErrorType.connection,
            message: 'Unable to connect to the server.',
          );
        };

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      expect(success, isFalse);

      expect(cubit.state.phase, AddWishlistEntryPhase.failure);

      expect(cubit.state.errorMessage, 'Unable to connect to the server.');
    });

    test('handles unexpected failures', () async {
      final repository = FakeWishlistWritesRepository()
        ..addHandler = () async {
          throw StateError('Unexpected failure');
        };

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final success = await cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      expect(success, isFalse);
      expect(cubit.state.phase, AddWishlistEntryPhase.failure);

      expect(
        cubit.state.errorMessage,
        'Unable to update your wishlist. Please try again.',
      );
    });

    test('allows retrying after a failure', () async {
      final repository = FakeWishlistWritesRepository();

      repository.addHandler = () async {
        if (repository.addCalls == 1) {
          throw StateError('Temporary failure');
        }

        return createdResult();
      };

      final cubit = AddWishlistEntryCubit(repository: repository);

      addTearDown(cubit.close);

      final input = WishlistEntryInput.country(countryCode: 'PT');

      expect(await cubit.submit(input: input), isFalse);

      expect(cubit.state.phase, AddWishlistEntryPhase.failure);

      cubit.clearError();

      expect(cubit.state.phase, AddWishlistEntryPhase.idle);

      expect(await cubit.submit(input: input), isTrue);

      expect(repository.addCalls, 2);
    });

    test('does not emit after being closed during submission', () async {
      final completer = Completer<WishlistCreationResult>();

      final repository = FakeWishlistWritesRepository()
        ..addHandler = () => completer.future;

      final cubit = AddWishlistEntryCubit(repository: repository);

      final saving = cubit.submit(
        input: WishlistEntryInput.country(countryCode: 'PT'),
      );

      await cubit.close();

      completer.complete(createdResult());

      expect(await saving, isFalse);
      expect(cubit.isClosed, isTrue);
    });
  });
}
