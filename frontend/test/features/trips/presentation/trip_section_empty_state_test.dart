import 'package:beenaround/features/trips/presentation/widgets/trip_section_empty_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEmptyState(
    WidgetTester tester, {
    VoidCallback? onAction,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripSectionEmptyState(
              key: const Key('testTripEmptyState'),
              title: 'No countries added',
              message:
                  'Add country visits to record the destinations '
                  'in this Trip.',
              icon: Icons.public_outlined,
              actionLabel: 'Add countries',
              actionKey: const Key('testTripEmptyStateAction'),
              onAction: onAction,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows title, message and action', (tester) async {
    await pumpEmptyState(tester);

    expect(find.text('No countries added'), findsOneWidget);

    expect(
      find.text(
        'Add country visits to record the destinations '
        'in this Trip.',
      ),
      findsOneWidget,
    );

    expect(find.byKey(const Key('testTripEmptyStateAction')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes the provided action', (tester) async {
    var actionCalls = 0;

    await pumpEmptyState(tester, onAction: () => actionCalls++);

    await tester.tap(find.byKey(const Key('testTripEmptyStateAction')));

    expect(actionCalls, 1);
  });

  testWidgets('disables the action when callback is null', (tester) async {
    await pumpEmptyState(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('testTripEmptyStateAction')),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('does not overflow at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpEmptyState(tester, onAction: () {});

    expect(find.byKey(const Key('testTripEmptyState')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow at 390px width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpEmptyState(tester, onAction: () {});

    expect(tester.takeException(), isNull);
  });
}
