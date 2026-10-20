import 'dart:async';

import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/features/auth/application/login_cubit.dart';
import 'package:beenaround/features/auth/data/login_repository.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:beenaround/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLoginRepository implements LoginRepository {
  String? receivedLogin;
  String? receivedPassword;
  LoginFailure? failure;
  Completer<LoginResult>? pendingResult;
  int callCount = 0;

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    callCount++;
    receivedLogin = login;
    receivedPassword = password;

    if (pendingResult != null) {
      return pendingResult!.future;
    }

    if (failure != null) {
      throw LoginException(failure!);
    }

    return successfulResult;
  }
}

const successfulResult = LoginResult(
  user: AuthenticatedUser(
    id: 'user-1',
    username: 'goncalo',
    displayName: 'Gonçalo',
    isAdmin: true,
  ),
);

void main() {
  late FakeLoginRepository repository;
  late LoginCubit cubit;
  late List<LoginResult> authenticatedResults;

  setUp(() {
    repository = FakeLoginRepository();
    cubit = LoginCubit(repository: repository);
    authenticatedResults = [];
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider.value(
          value: cubit,
          child: LoginPage(onAuthenticated: authenticatedResults.add),
        ),
      ),
    );
  }

  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      '  goncalo  ',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'test-password',
    );

    await tester.pump();
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Sign In');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pump();
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    final mode = theme.brightness == Brightness.dark ? 'Dark' : 'Light';

    group('$mode Mode', () {
      testWidgets('renders the login form with theme colors', (tester) async {
        await pumpLogin(tester, theme: theme);

        expect(find.text('BeenAround'), findsOneWidget);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

        expect(scaffold.backgroundColor, isNull);

        final compass = tester.widget<Icon>(
          find.byIcon(Icons.explore_outlined),
        );

        expect(compass.color, theme.colorScheme.primary);
      });

      testWidgets('validates empty credentials', (tester) async {
        await pumpLogin(tester, theme: theme);

        await tapSignIn(tester);

        expect(find.text('Enter your username or email.'), findsOneWidget);

        expect(find.text('Enter your password.'), findsOneWidget);

        expect(repository.callCount, 0);
      });

      testWidgets('toggles password visibility', (tester) async {
        await pumpLogin(tester, theme: theme);

        final passwordField = find.widgetWithText(TextFormField, 'Password');

        EditableText editableText() {
          return tester.widget<EditableText>(
            find.descendant(
              of: passwordField,
              matching: find.byType(EditableText),
            ),
          );
        }

        expect(editableText().obscureText, isTrue);

        await tester.tap(find.byTooltip('Toggle password visibility'));
        await tester.pump();

        expect(editableText().obscureText, isFalse);

        await tester.tap(find.byTooltip('Toggle password visibility'));
        await tester.pump();

        expect(editableText().obscureText, isTrue);
      });

      testWidgets('submits credentials and calls onAuthenticated', (
        tester,
      ) async {
        await pumpLogin(tester, theme: theme);
        await enterCredentials(tester);

        await tapSignIn(tester);
        await tester.pump();

        expect(repository.callCount, 1);
        expect(repository.receivedLogin, 'goncalo');
        expect(repository.receivedPassword, 'test-password');

        expect(authenticatedResults, hasLength(1));
        expect(authenticatedResults.single.user.username, 'goncalo');
      });

      testWidgets('disables Sign In while submitting', (tester) async {
        final completer = Completer<LoginResult>();
        repository.pendingResult = completer;

        await pumpLogin(tester, theme: theme);
        await enterCredentials(tester);

        await tapSignIn(tester);

        final button = tester.widget<FilledButton>(find.byType(FilledButton));

        expect(button.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(repository.callCount, 1);

        completer.complete(successfulResult);
        await tester.pump();

        expect(authenticatedResults, hasLength(1));
      });

      testWidgets('displays invalid credentials error', (tester) async {
        repository.failure = LoginFailure.invalidCredentials;

        await pumpLogin(tester, theme: theme);
        await enterCredentials(tester);

        await tapSignIn(tester);
        await tester.pump();

        expect(
          find.text('Invalid username/email or password.'),
          findsOneWidget,
        );

        expect(authenticatedResults, isEmpty);
      });

      testWidgets('displays unavailable server error', (tester) async {
        repository.failure = LoginFailure.unavailable;

        await pumpLogin(tester, theme: theme);
        await enterCredentials(tester);

        await tapSignIn(tester);
        await tester.pump();

        expect(
          find.text('Unable to connect to the server. Please try again.'),
          findsOneWidget,
        );

        expect(authenticatedResults, isEmpty);
      });
    });
  }
}
