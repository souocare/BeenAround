import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/app/widgets/app_empty_state.dart';
import 'package:beenaround/app/widgets/app_error_state.dart';
import 'package:beenaround/app/widgets/app_loading_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;

    group('${brightness.name} theme', () {
      Future<void> pumpState(WidgetTester tester, Widget child) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: child),
          ),
        );
      }

      testWidgets('empty state displays title and message', (tester) async {
        await pumpState(
          tester,
          const AppEmptyState(
            title: 'No countries yet',
            message: 'Start recording your travels.',
          ),
        );

        expect(find.text('No countries yet'), findsOneWidget);
        expect(find.text('Start recording your travels.'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty state invokes its action', (tester) async {
        var calls = 0;

        await pumpState(
          tester,
          AppEmptyState(
            title: 'No countries yet',
            message: 'Start recording your travels.',
            actionLabel: 'Add Country',
            onAction: () => calls++,
          ),
        );

        await tester.tap(find.text('Add Country'));

        expect(calls, 1);
      });

      testWidgets('error state displays message without retry', (tester) async {
        await pumpState(
          tester,
          const AppErrorState(message: 'Unable to load countries.'),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Unable to load countries.'), findsOneWidget);
        expect(find.text('Try Again'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error state invokes retry callback', (tester) async {
        var calls = 0;

        await pumpState(
          tester,
          AppErrorState(
            message: 'Unable to load countries.',
            onRetry: () => calls++,
          ),
        );

        await tester.tap(find.text('Try Again'));

        expect(calls, 1);
      });

      testWidgets('loading state displays progress indicator', (tester) async {
        await pumpState(tester, const AppLoadingState());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('loading state displays optional message', (tester) async {
        await pumpState(
          tester,
          const AppLoadingState(message: 'Loading your travels...'),
        );

        expect(find.text('Loading your travels...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  }
}
