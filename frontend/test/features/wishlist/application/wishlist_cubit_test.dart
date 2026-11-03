import 'dart:async';

import 'package:beenaround/features/wishlist/application/wishlist_cubit.dart';
import 'package:beenaround/features/wishlist/application/wishlist_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wishlist_repository.dart';

WishlistEntry makeWishlistEntry({
  required String id,
  String? countryCode,
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

void main() {
  group('WishlistCubit', () {
    test('starts with an initial state', () async {
      final cubit = WishlistCubit(repository: FakeWishlistRepository());

      expect(cubit.state.phase, WishlistPhase.initial);
      expect(cubit.state.entries, isEmpty);

      await cubit.close();
    });

    test('loads country and city wishlist entries', () async {
      final repository = FakeWishlistRepository()
        ..entries = [
          makeWishlistEntry(id: 'country', countryCode: 'PT'),
          makeWishlistEntry(id: 'city', cityId: 2267057),
        ];

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.loadCalls, 1);
      expect(cubit.state.phase, WishlistPhase.ready);

      expect(cubit.state.totalEntries, 2);
      expect(cubit.state.countryCount, 1);
      expect(cubit.state.cityCount, 1);

      expect(cubit.state.containsCountry('PT'), isTrue);
      expect(cubit.state.containsCity(2267057), isTrue);
    });

    test('does not derive country wishlist from city entries', () async {
      final repository = FakeWishlistRepository()
        ..entries = [makeWishlistEntry(id: 'city', cityId: 2267057)];

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.containsCity(2267057), isTrue);
      expect(cubit.state.containsCountry('PT'), isFalse);
    });

    test('preserves optional notes', () async {
      final repository = FakeWishlistRepository()
        ..entries = [
          makeWishlistEntry(
            id: 'country',
            countryCode: 'PT',
            note: 'Explore the Azores.',
          ),
        ];

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      final entry = cubit.state.entryForCountry('PT');

      expect(entry, isNotNull);
      expect(entry!.note, 'Explore the Azores.');
    });

    test('preserves existing entries when refresh fails', () async {
      final repository = FakeWishlistRepository()
        ..entries = [makeWishlistEntry(id: 'country', countryCode: 'PT')];

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      repository.error = StateError('Network unavailable');

      await cubit.refresh();

      expect(cubit.state.phase, WishlistPhase.failure);
      expect(cubit.state.totalEntries, 1);
    });

    test('exposes loading state while pending', () async {
      final completer = Completer<List<WishlistEntry>>();

      final repository = FakeWishlistRepository()
        ..loadHandler = () => completer.future;

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      final loading = cubit.load();

      expect(cubit.state.phase, WishlistPhase.loading);

      completer.complete([makeWishlistEntry(id: 'country', countryCode: 'PT')]);

      await loading;

      expect(cubit.state.phase, WishlistPhase.ready);
    });

    test('ignores outdated responses', () async {
      final first = Completer<List<WishlistEntry>>();
      final second = Completer<List<WishlistEntry>>();

      var calls = 0;

      final repository = FakeWishlistRepository()
        ..loadHandler = () {
          calls++;

          return calls == 1 ? first.future : second.future;
        };

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      final firstLoad = cubit.load();
      final secondLoad = cubit.load();

      second.complete([makeWishlistEntry(id: 'new', countryCode: 'PT')]);

      await secondLoad;

      first.complete([makeWishlistEntry(id: 'old', countryCode: 'ES')]);

      await firstLoad;

      expect(cubit.state.entries.single.id, 'new');
      expect(cubit.state.containsCountry('PT'), isTrue);
      expect(cubit.state.containsCountry('ES'), isFalse);
    });

    test('does not emit after close', () async {
      final completer = Completer<List<WishlistEntry>>();

      final repository = FakeWishlistRepository()
        ..loadHandler = () => completer.future;

      final cubit = WishlistCubit(repository: repository);

      final loading = cubit.load();

      await cubit.close();

      completer.complete([]);

      await loading;

      expect(cubit.isClosed, isTrue);
    });

    test('exposes immutable collections', () async {
      final repository = FakeWishlistRepository()
        ..entries = [makeWishlistEntry(id: 'country', countryCode: 'PT')];

      final cubit = WishlistCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(() => cubit.state.entries.clear(), throwsUnsupportedError);

      expect(() => cubit.state.countryCodes.clear(), throwsUnsupportedError);
    });
  });
}
