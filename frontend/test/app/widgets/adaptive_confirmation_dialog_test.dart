import 'package:beenaround/app/widgets/adaptive_confirmation_dialog.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> openDialog(
    WidgetTester tester, {
    required TargetPlatform platform,
    bool isDestructive = false,
  }) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showAdaptiveConfirmationDialog(
                    context,
                    title: 'Discard changes?',
                    message: 'You have unsaved changes.',
                    confirmLabel: 'Discard Changes',
                    cancelLabel: 'Keep Editing',
                    isDestructive: isDestructive,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    return result;
  }

  group('AdaptiveConfirmationDialog', () {
    testWidgets('uses Cupertino on iOS', (tester) async {
      await openDialog(tester, platform: TargetPlatform.iOS);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('uses Cupertino on macOS', (tester) async {
      await openDialog(tester, platform: TargetPlatform.macOS);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    });

    testWidgets('uses Material on Android', (tester) async {
      await openDialog(tester, platform: TargetPlatform.android);

      expect(find.byType(AlertDialog), findsOneWidget);

      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('uses Material on Windows', (tester) async {
      await openDialog(tester, platform: TargetPlatform.windows);

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showAdaptiveConfirmationDialog(
                      context,
                      title: 'Discard changes?',
                      message: 'Unsaved changes.',
                      confirmLabel: 'Discard Changes',
                      cancelLabel: 'Keep Editing',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('confirmation returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showAdaptiveConfirmationDialog(
                      context,
                      title: 'Discard changes?',
                      message: 'Unsaved changes.',
                      confirmLabel: 'Discard Changes',
                      cancelLabel: 'Keep Editing',
                      isDestructive: true,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('marks Cupertino confirmation as destructive', (tester) async {
      await openDialog(
        tester,
        platform: TargetPlatform.iOS,
        isDestructive: true,
      );

      final actions = tester.widgetList<CupertinoDialogAction>(
        find.byType(CupertinoDialogAction),
      );

      expect(actions.any((action) => action.isDestructiveAction), isTrue);
    });
  });
}
