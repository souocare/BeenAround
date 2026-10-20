import 'dart:async';

import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/features/auth/application/first_run_setup_cubit.dart';
import 'package:beenaround/features/auth/data/first_run_setup_repository.dart';
import 'package:beenaround/features/auth/presentation/pages/first_run_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirstRunSetupRepository implements FirstRunSetupRepository {
  FirstRunSetupRequest? lastRequest;
  FirstRunSetupFailure? failure;
  Completer<void>? pendingResult;
  int callCount = 0;

  @override
  Future<void> createAdministrator(FirstRunSetupRequest request) async {
    callCount++;
    lastRequest = request;

    if (pendingResult != null) {
      return pendingResult!.future;
    }

    if (failure != null) {
      throw FirstRunSetupException(failure!);
    }
  }
}

void main() {
  late FakeFirstRunSetupRepository repository;
  late FirstRunSetupCubit cubit;
  late int completedCount;

  setUp(() {
    repository = FakeFirstRunSetupRepository();
    cubit = FirstRunSetupCubit(repository: repository);
    completedCount = 0;
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pumpSetup(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider.value(
          value: cubit,
          child: FirstRunSetupPage(onCompleted: () => completedCount++),
        ),
      ),
    );
  }

  Finder fieldAt(int index) {
    return find.byType(TextFormField).at(index);
  }

  Future<void> enterValidDetails(WidgetTester tester) async {
    await tester.enterText(fieldAt(0), '  Gonçalo  ');
    await tester.enterText(fieldAt(1), '  Goncalo  ');
    await tester.enterText(fieldAt(2), '');
    await tester.enterText(fieldAt(3), 'a-strong-password');
    await tester.enterText(fieldAt(4), 'a-strong-password');

    await tester.pump();
  }

  Future<void> tapCreateAdministrator(WidgetTester tester) async {
    final button = find.widgetWithText(
      FilledButton,
      'Create Administrator Account',
    );

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pump();
  }

  EditableText editableTextFor(WidgetTester tester, int fieldIndex) {
    return tester.widget<EditableText>(
      find.descendant(
        of: fieldAt(fieldIndex),
        matching: find.byType(EditableText),
      ),
    );
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    final mode = theme.brightness == Brightness.dark ? 'Dark' : 'Light';

    group('$mode Mode', () {
      testWidgets('renders administrator setup with theme colors', (
        tester,
      ) async {
        await pumpSetup(tester, theme: theme);

        expect(find.text('BeenAround'), findsOneWidget);
        expect(find.text('Welcome to BeenAround'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(5));

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

        expect(scaffold.backgroundColor, isNull);

        final compass = tester.widget<Icon>(
          find.byIcon(Icons.explore_outlined),
        );

        expect(compass.color, theme.colorScheme.primary);
      });

      testWidgets('validates required fields and password length', (
        tester,
      ) async {
        await pumpSetup(tester, theme: theme);

        await tapCreateAdministrator(tester);

        expect(find.text('This field is required.'), findsOneWidget);

        expect(
          find.text('Use 3–32 letters, numbers or underscores.'),
          findsOneWidget,
        );

        expect(find.text('Use at least 12 characters.'), findsOneWidget);

        expect(repository.callCount, 0);
      });

      testWidgets('rejects mismatched passwords', (tester) async {
        await pumpSetup(tester, theme: theme);
        await enterValidDetails(tester);

        await tester.enterText(fieldAt(4), 'different-password');

        await tapCreateAdministrator(tester);

        expect(find.text('Passwords do not match.'), findsOneWidget);

        expect(repository.callCount, 0);
      });

      testWidgets('toggles both password fields independently', (tester) async {
        await pumpSetup(tester, theme: theme);

        expect(editableTextFor(tester, 3).obscureText, isTrue);
        expect(editableTextFor(tester, 4).obscureText, isTrue);

        await tester.ensureVisible(
          find.byTooltip('Toggle password visibility'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Toggle password visibility'));
        await tester.pump();

        expect(editableTextFor(tester, 3).obscureText, isFalse);
        expect(editableTextFor(tester, 4).obscureText, isTrue);

        await tester.ensureVisible(
          find.byTooltip('Toggle confirmation visibility'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Toggle confirmation visibility'));
        await tester.pump();

        expect(editableTextFor(tester, 3).obscureText, isFalse);
        expect(editableTextFor(tester, 4).obscureText, isFalse);
      });

      testWidgets('creates administrator and calls onCompleted', (
        tester,
      ) async {
        await pumpSetup(tester, theme: theme);
        await enterValidDetails(tester);

        await tapCreateAdministrator(tester);
        await tester.pump();

        expect(repository.callCount, 1);

        expect(repository.lastRequest?.displayName, 'Gonçalo');
        expect(repository.lastRequest?.username, 'goncalo');
        expect(repository.lastRequest?.email, isNull);
        expect(repository.lastRequest?.password, 'a-strong-password');

        expect(completedCount, 1);
      });

      testWidgets('disables submission while creating administrator', (
        tester,
      ) async {
        final completer = Completer<void>();
        repository.pendingResult = completer;

        await pumpSetup(tester, theme: theme);
        await enterValidDetails(tester);

        await tapCreateAdministrator(tester);

        final button = tester.widget<FilledButton>(find.byType(FilledButton));

        expect(button.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(repository.callCount, 1);
        expect(completedCount, 0);

        completer.complete();

        await tester.pump();
        await tester.pump();

        expect(completedCount, 1);
      });

      testWidgets('displays already completed setup error', (tester) async {
        repository.failure = FirstRunSetupFailure.alreadyCompleted;

        await pumpSetup(tester, theme: theme);
        await enterValidDetails(tester);

        await tapCreateAdministrator(tester);
        await tester.pump();

        expect(
          find.text('Initial setup has already been completed.'),
          findsOneWidget,
        );

        expect(completedCount, 0);
      });

      testWidgets('displays unavailable server error', (tester) async {
        repository.failure = FirstRunSetupFailure.unavailable;

        await pumpSetup(tester, theme: theme);
        await enterValidDetails(tester);

        await tapCreateAdministrator(tester);
        await tester.pump();

        expect(
          find.text('Unable to reach the server. Please try again.'),
          findsOneWidget,
        );

        expect(completedCount, 0);
      });
    });
  }
}
