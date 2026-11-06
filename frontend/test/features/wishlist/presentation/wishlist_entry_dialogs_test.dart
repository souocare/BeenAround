import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';
import 'package:beenaround/features/wishlist/presentation/widgets/show_edit_wishlist_note.dart';
import 'package:beenaround/features/wishlist/presentation/widgets/show_remove_wishlist_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/fake_wishlist_repository.dart';

class FakeWishlistActionsRepository extends FakeWishlistRepository {
  int deleteCalls = 0;
  int updateCalls = 0;

  String? deletedEntryId;
  String? updatedEntryId;
  String? updatedNote;

  bool failDelete = false;
  bool failUpdate = false;

  @override
  Future<void> deleteWishlistEntry({required String entryId}) async {
    deleteCalls++;
    deletedEntryId = entryId;

    if (failDelete) {
      throw StateError('Delete failed');
    }

    entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) async {
    updateCalls++;
    updatedEntryId = entryId;
    updatedNote = note;

    if (failUpdate) {
      throw StateError('Update failed');
    }

    final previous = entries.firstWhere((entry) => entry.id == entryId);

    final updated = WishlistEntry(
      id: previous.id,
      countryCode: previous.countryCode,
      cityId: previous.cityId,
      note: note,
      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 11, 6),
    );

    final index = entries.indexWhere((entry) => entry.id == entryId);
    entries[index] = updated;

    return updated;
  }
}

WishlistEntry makeCountryWishlistEntry({String? note}) {
  return WishlistEntry(
    id: 'wishlist-portugal',
    countryCode: 'PT',
    cityId: null,
    note: note,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

Future<void> pumpWishlistDialog(
  WidgetTester tester, {
  required FakeWishlistActionsRepository repository,
  required WishlistEntry entry,
  required bool editNote,
  required ValueChanged<bool> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RepositoryProvider<WishlistRepository>.value(
        value: repository,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  key: const Key('openWishlistDialog'),
                  onPressed: () async {
                    final result = editNote
                        ? await showEditWishlistNote(
                            context: context,
                            entry: entry,
                          )
                        : await showRemoveWishlistEntry(
                            context: context,
                            entry: entry,
                            destinationName: 'Portugal',
                          );

                    onResult(result);
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Remove Wishlist Entry', () {
    testWidgets('opens confirmation when requested', (tester) async {
      final entry = makeCountryWishlistEntry();

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: false,
        onResult: (_) {},
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Wishlist?'), findsOneWidget);
      expect(find.byKey(const Key('confirmRemoveWishlist')), findsOneWidget);
      expect(repository.deleteCalls, 0);
    });

    testWidgets('cancel does not delete wishlist entry', (tester) async {
      final entry = makeCountryWishlistEntry();

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      bool? result;

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: false,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancelRemoveWishlist')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(repository.deleteCalls, 0);
      expect(repository.entries, contains(entry));
    });

    testWidgets('confirm deletes correct wishlist entry', (tester) async {
      final entry = makeCountryWishlistEntry();

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      bool? result;

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: false,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmRemoveWishlist')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.deletedEntryId, 'wishlist-portugal');
      expect(repository.entries, isEmpty);
      expect(find.text('Remove from Wishlist?'), findsNothing);
    });

    testWidgets('delete failure keeps confirmation open', (tester) async {
      final entry = makeCountryWishlistEntry();

      final repository = FakeWishlistActionsRepository()
        ..entries = [entry]
        ..failDelete = true;

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: false,
        onResult: (_) {},
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmRemoveWishlist')));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Wishlist?'), findsOneWidget);
      expect(find.byKey(const Key('removeWishlistError')), findsOneWidget);

      expect(repository.deleteCalls, 1);
      expect(repository.entries, contains(entry));
    });
  });

  group('Edit Wishlist Note', () {
    testWidgets('loads existing note', (tester) async {
      final entry = makeCountryWishlistEntry(note: 'Visit Porto');

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: true,
        onResult: (_) {},
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('wishlistNoteField')),
      );

      expect(field.controller?.text, 'Visit Porto');
    });

    testWidgets('saves updated wishlist note', (tester) async {
      final entry = makeCountryWishlistEntry(note: 'Old note');

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      bool? result;

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: true,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wishlistNoteField')),
        'Explore the Azores',
      );

      await tester.tap(find.byKey(const Key('saveWishlistNoteButton')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(repository.updateCalls, 1);
      expect(repository.updatedEntryId, 'wishlist-portugal');
      expect(repository.updatedNote, 'Explore the Azores');
      expect(repository.entries.single.note, 'Explore the Azores');
    });

    testWidgets('clearing note sends null to repository', (tester) async {
      final entry = makeCountryWishlistEntry(note: 'Old note');

      final repository = FakeWishlistActionsRepository()..entries = [entry];

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: true,
        onResult: (_) {},
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('wishlistNoteField')), '');

      await tester.tap(find.byKey(const Key('saveWishlistNoteButton')));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.updatedNote, isNull);
      expect(repository.entries.single.note, isNull);
    });

    testWidgets('update failure keeps dialog open', (tester) async {
      final entry = makeCountryWishlistEntry(note: 'Old note');

      final repository = FakeWishlistActionsRepository()
        ..entries = [entry]
        ..failUpdate = true;

      await pumpWishlistDialog(
        tester,
        repository: repository,
        entry: entry,
        editNote: true,
        onResult: (_) {},
      );

      await tester.tap(find.byKey(const Key('openWishlistDialog')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wishlistNoteField')),
        'Updated note',
      );

      await tester.tap(find.byKey(const Key('saveWishlistNoteButton')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Wishlist Note'), findsOneWidget);
      expect(find.byKey(const Key('wishlistNoteError')), findsOneWidget);

      expect(repository.updateCalls, 1);
      expect(repository.entries.single.note, 'Old note');
    });
  });
}
