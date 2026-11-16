import 'package:beenaround/app/widgets/adaptive_confirmation_dialog.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildTestApp(TargetPlatform platform) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return FilledButton(
            onPressed: () {
              showAdaptiveConfirmationDialog(
                context,
                title: 'Remove association?',
                message: 'The original record will remain available.',
                confirmLabel: 'Remove',
                cancelLabel: 'Cancel',
                isDestructive: true,
                dialogKey: const Key('testConfirmationDialog'),
                confirmButtonKey: const Key('testConfirmButton'),
                cancelButtonKey: const Key('testCancelButton'),
              );
            },
            child: const Text('Open confirmation'),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('uses CupertinoAlertDialog on iOS', (tester) async {
    await tester.pumpWidget(buildTestApp(TargetPlatform.iOS));

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    expect(find.byKey(const Key('testConfirmationDialog')), findsOneWidget);

    expect(find.byKey(const Key('testCancelButton')), findsOneWidget);
    expect(find.byKey(const Key('testConfirmButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('testCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('uses AlertDialog on Android', (tester) async {
    await tester.pumpWidget(buildTestApp(TargetPlatform.android));

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);

    expect(find.byKey(const Key('testConfirmationDialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('testConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
