import 'dart:async';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/features/auth/data/login_repository.dart';
import 'package:beenaround/features/auth/data/secure_token_storage.dart';
import 'package:beenaround/features/auth/data/session_repository.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:beenaround/features/auth/domain/mobile_session.dart';
import 'package:beenaround/features/auth/presentation/authentication_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/app/shell/authenticated_app_shell.dart';
import 'package:beenaround/app/theme/theme_cubit.dart';
import 'package:beenaround/app/theme/theme_preference_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const testUser = AuthenticatedUser(
  id: 'user-1',
  username: 'goncalo',
  displayName: 'Gonçalo',
  isAdmin: true,
);

class FakeLoginRepository implements LoginRepository {
  int calls = 0;
  LoginException? error;

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    calls++;

    if (error != null) throw error!;

    return const LoginResult(
      user: testUser,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }
}

class FakeSessionRepository implements SessionRepository {
  AuthenticatedUser user = testUser;

  SessionException? currentUserError;
  SessionException? refreshError;

  Completer<AuthenticatedUser>? currentUserCompleter;

  int currentUserCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthenticatedUser> getCurrentUser({String? accessToken}) async {
    currentUserCalls++;

    if (currentUserCompleter != null) {
      return currentUserCompleter!.future;
    }

    if (currentUserError != null) {
      throw currentUserError!;
    }

    return user;
  }

  @override
  Future<MobileSession> refreshMobileSession(String refreshToken) async {
    refreshCalls++;

    if (refreshError != null) throw refreshError!;

    return const MobileSession(
      accessToken: 'restored-access',
      refreshToken: 'rotated-refresh',
      expiresIn: 900,
    );
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutCalls++;
  }
}

class FakeTokenStorage implements SecureTokenStorage {
  String? token;
  bool failWrites = false;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String value) async {
    if (failWrites) throw StateError('Storage unavailable');
    token = value;
  }

  @override
  Future<void> deleteRefreshToken() async {
    token = null;
  }
}

void main() {
  late FakeLoginRepository loginRepository;
  late FakeSessionRepository sessionRepository;
  late FakeTokenStorage tokenStorage;
  late ThemeCubit themeCubit;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    loginRepository = FakeLoginRepository();
    sessionRepository = FakeSessionRepository();
    tokenStorage = FakeTokenStorage();

    themeCubit = ThemeCubit(
      repository: ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      ),
    );
  });
  tearDown(() async {
    await themeCubit.close();
  });

  ServerConfig server(String address) {
    return ServerConfig.parse(address)!;
  }

  Widget createApp({
    bool isWeb = false,
    String address = 'https://travel.example.com',
  }) {
    final config = server(address);

    return BlocProvider.value(
      value: themeCubit,
      child: MaterialApp(
        home: AuthenticationGateway(
          key: ValueKey(config.baseUrl.toString()),
          serverConfig: config,
          isWeb: isWeb,
          dependenciesFactory: (_, _, _) => AuthenticationDependencies(
            loginRepository: loginRepository,
            sessionRepository: sessionRepository,
            tokenStorage: isWeb ? null : tokenStorage,
          ),
        ),
      ),
    );
  }

  testWidgets('shows login when no mobile session exists', (tester) async {
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(sessionRepository.refreshCalls, 0);
  });

  testWidgets('restores an existing mobile session', (tester) async {
    tokenStorage.token = 'stored-refresh';

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
    expect(sessionRepository.refreshCalls, 1);
    expect(tokenStorage.token, 'rotated-refresh');
  });

  testWidgets('restores an existing Web session', (tester) async {
    await tester.pumpWidget(createApp(isWeb: true));
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
    expect(sessionRepository.currentUserCalls, 1);
    expect(sessionRepository.refreshCalls, 0);
  });

  testWidgets('shows login when Web session is unauthorized', (tester) async {
    sessionRepository.currentUserError = const SessionException(
      SessionFailure.unauthorized,
    );

    await tester.pumpWidget(createApp(isWeb: true));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('successful login opens authenticated home', (tester) async {
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'goncalo');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(loginRepository.calls, 1);
    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
    expect(tokenStorage.token, 'refresh-token');
  });

  testWidgets('logout returns to login', (tester) async {
    tokenStorage.token = 'stored-refresh';

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedAppShell), findsOneWidget);

    // Navigate to Profile.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Logout.
    // Scroll to the logout action before tapping.
    final signOutButton = find.widgetWithText(FilledButton, 'Sign Out');

    await tester.ensureVisible(signOutButton);
    await tester.pumpAndSettle();

    await tester.tap(signOutButton);
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(sessionRepository.logoutCalls, 1);
    expect(tokenStorage.token, isNull);
  });

  testWidgets('unavailable restoration shows retry', (tester) async {
    tokenStorage.token = 'stored-refresh';
    sessionRepository.refreshError = const SessionException(
      SessionFailure.unavailable,
    );

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.text('Unable to restore your session.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(tokenStorage.token, 'stored-refresh');

    sessionRepository.refreshError = null;

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
  });

  testWidgets('storage failure allows login retry', (tester) async {
    tokenStorage.failWrites = true;

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'goncalo');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);

    tokenStorage.failWrites = false;

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');

    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();

    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(loginRepository.calls, 2);
    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
  });

  testWidgets('changing server creates a new authentication session', (
    tester,
  ) async {
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);

    await tester.pumpWidget(createApp(address: 'https://another.example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(sessionRepository.currentUserCalls, 0);
  });

  testWidgets('shows loading while restoring Web session', (tester) async {
    sessionRepository.currentUserCompleter = Completer<AuthenticatedUser>();

    await tester.pumpWidget(createApp(isWeb: true));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    sessionRepository.currentUserCompleter!.complete(testUser);
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedAppShell), findsOneWidget);
  });
}
