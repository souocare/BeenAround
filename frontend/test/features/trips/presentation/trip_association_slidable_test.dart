import 'dart:async';

import 'package:beenaround/features/trips/presentation/widgets/trip_association_slidable.dart';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp({
    required Future<void> Function() onRemoveRequested,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TripAssociationSlidable(
              associationId: 'visit-1',
              removeLabel: 'Remove',
              enabled: enabled,
              onRemoveRequested: onRemoveRequested,
              child: const ListTile(
                key: Key('testTripAssociation'),
                title: Text('Sri Lanka'),
                subtitle: Text('Sep 27 – Oct 4'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('reveals Remove after swiping left', (tester) async {
    var removeRequests = 0;

    await tester.pumpWidget(
      buildTestApp(
        onRemoveRequested: () async {
          removeRequests++;
        },
      ),
    );

    await tester.drag(
      find.byKey(const Key('testTripAssociation')),
      const Offset(-120, 0),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('removeSwipe-visit-1')), findsOneWidget);

    expect(removeRequests, 0);
  });

  testWidgets('Remove action invokes the confirmation callback', (
    tester,
  ) async {
    var removeRequests = 0;

    await tester.pumpWidget(
      buildTestApp(
        onRemoveRequested: () async {
          removeRequests++;
        },
      ),
    );

    await tester.drag(
      find.byKey(const Key('testTripAssociation')),
      const Offset(-120, 0),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('removeSwipe-visit-1')));

    await tester.pumpAndSettle();

    expect(removeRequests, 1);
  });

  testWidgets('disabled association cannot request removal', (tester) async {
    var removeRequests = 0;

    await tester.pumpWidget(
      buildTestApp(
        enabled: false,
        onRemoveRequested: () async {
          removeRequests++;
        },
      ),
    );

    await tester.drag(
      find.byKey(const Key('testTripAssociation')),
      const Offset(-120, 0),
    );

    await tester.pumpAndSettle();

    expect(removeRequests, 0);

    expect(tester.takeException(), isNull);
  });
  testWidgets('prevents overlapping removal requests', (tester) async {
    final removalDelay = Completer<void>();
    var removeRequests = 0;

    await tester.pumpWidget(
      buildTestApp(
        onRemoveRequested: () async {
          removeRequests++;
          await removalDelay.future;
        },
      ),
    );

    await tester.drag(
      find.byKey(const Key('testTripAssociation')),
      const Offset(-120, 0),
    );

    await tester.pumpAndSettle();

    final deleteAction = find.byKey(const ValueKey('removeSwipe-visit-1'));

    await tester.tap(deleteAction);
    await tester.pump();

    expect(removeRequests, 1);

    // Trigger another request while the first is still pending.
    // The component must ignore it.
    final slidable = tester.widget<Slidable>(
      find.byKey(const ValueKey('slidable-visit-1')),
    );
    // Keep Slidable's gesture controller stable during removal.
    // Duplicate requests are blocked by _requestRemoval().
    expect(slidable.enabled, isTrue);

    // Attempt a second removal while the first is still pending.

    await tester.tap(deleteAction);

    await tester.pump();

    expect(removeRequests, 1);

    removalDelay.complete();
    await tester.pumpAndSettle();

    expect(removeRequests, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop provides Delete without requiring swipe', (
    tester,
  ) async {
    var removeRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: TripAssociationSlidable(
            associationId: 'visit-1',
            removeLabel: 'Delete',
            onRemoveRequested: () async {
              removeRequests++;
            },
            child: const ListTile(title: Text('Sri Lanka')),
          ),
        ),
      ),
    );

    final menu = find.byKey(const ValueKey('associationMenu-visit-1'));

    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(removeRequests, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('full swipe requests removal without dismissing the item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var removeRequests = 0;

    await tester.pumpWidget(
      buildTestApp(
        onRemoveRequested: () async {
          removeRequests++;
        },
      ),
    );

    await tester.pumpAndSettle();

    final association = find.byKey(const Key('testTripAssociation'));

    expect(association, findsOneWidget);

    final rect = tester.getRect(association);

    final gesture = await tester.startGesture(
      Offset(rect.right - 12, rect.center.dy),
    );

    // First movement allows the horizontal drag recognizer
    // to accept the gesture.
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 16));

    // Continue moving in smaller steps.
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      removeRequests,
      1,
      reason: 'A full swipe must invoke the removal callback.',
    );

    // Returning false from confirmDismiss must preserve
    // the widget until the caller updates the associations.
    expect(association, findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
