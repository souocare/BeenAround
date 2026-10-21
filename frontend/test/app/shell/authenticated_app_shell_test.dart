import 'package:beenaround/app/shell/authenticated_app_shell.dart';
import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/app/theme/theme_cubit.dart';
import 'package:beenaround/app/theme/theme_preference_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';

class FakeCountriesRepository implements CountriesRepository {
  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];
}

void main() {
  late ThemeCubit themeCubit;
  const user = AuthenticatedUser(
    id: 'user-1',
    username: 'goncalo',
    displayName: 'Gonçalo',
    isAdmin: true,
  );

  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Future<void> Function()? onLogout,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final exploreCubit = ExploreCubit(repository: FakeCountriesRepository());

    await exploreCubit.load();

    addTearDown(exploreCubit.close);
    themeCubit = ThemeCubit(
      repository: ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      ),
    );

    addTearDown(themeCubit.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: themeCubit),
          BlocProvider.value(value: exploreCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: AuthenticatedAppShell(
                user: user,
                onLogout: onLogout ?? () async {},
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  group('AuthenticatedAppShell', () {
    testWidgets('opens Explore by default on mobile', (tester) async {
      await pumpShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Countries visited'), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );

      expect(navigationBar.selectedIndex, 0);
    });

    testWidgets('mobile navigation switches between all destinations', (
      tester,
    ) async {
      await pumpShell(tester);

      final destinations = <String, String>{
        'Trips': 'Organize your travel memories.',
        'Map': 'Discover your travel history on the map.',
        'Statistics': 'Explore your travel statistics.',
      };

      for (final entry in destinations.entries) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(entry.key),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
      }

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gonçalo'), findsOneWidget);
      expect(find.text('@goncalo'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Explore'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Countries visited'), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);
    });

    testWidgets('wide layouts use top navigation', (tester) async {
      await pumpShell(tester, size: const Size(1200, 800));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('BeenAround'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Trips'));
      await tester.pumpAndSettle();

      expect(find.text('Organize your travel memories.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Statistics'));
      await tester.pumpAndSettle();

      expect(find.text('Explore your travel statistics.'), findsOneWidget);
    });

    testWidgets('switching layout preserves selected destination', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Trips'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Organize your travel memories.'), findsOneWidget);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Organize your travel memories.'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Organize your travel memories.'), findsOneWidget);

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );

      expect(navigationBar.selectedIndex, 1);
    });

    testWidgets('uses mobile navigation below breakpoint', (tester) async {
      await pumpShell(tester, size: const Size(799, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('uses top navigation at breakpoint', (tester) async {
      await pumpShell(tester, size: const Size(800, 800));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Profile displays authenticated user', (tester) async {
      await pumpShell(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gonçalo'), findsOneWidget);
      expect(find.text('@goncalo'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Profile invokes logout callback', (tester) async {
      var logoutCalls = 0;

      await pumpShell(
        tester,
        onLogout: () async {
          logoutCalls++;
        },
      );

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
    });
    testWidgets('desktop navigation highlights the selected destination', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1200, 800));

      final exploreButton = find.ancestor(
        of: find.text('Explore'),
        matching: find.byType(TextButton),
      );

      expect(exploreButton, findsOneWidget);

      final exploreWidget = tester.widget<TextButton>(exploreButton);

      expect(
        exploreWidget.style?.backgroundColor?.resolve({}),
        isNot(Colors.transparent),
      );

      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      final tripsButton = find.ancestor(
        of: find.text('Trips'),
        matching: find.byType(TextButton),
      );

      final tripsWidget = tester.widget<TextButton>(tripsButton);

      expect(
        tripsWidget.style?.backgroundColor?.resolve({}),
        isNot(Colors.transparent),
      );

      final updatedExploreWidget = tester.widget<TextButton>(exploreButton);

      expect(
        updatedExploreWidget.style?.backgroundColor?.resolve({}),
        Colors.transparent,
      );
    });
    testWidgets('desktop navigation fits at the breakpoint', (tester) async {
      await pumpShell(tester, size: const Size(800, 800));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      expect(tester.takeException(), isNull);
    });
    testWidgets('desktop navigation switches between all destinations', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1200, 800));

      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      expect(find.text('Organize your travel memories.'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(
        find.text('Discover your travel history on the map.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      expect(find.text('Explore your travel statistics.'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Gonçalo'), findsOneWidget);

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.text('Countries visited'), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);
    });
    testWidgets('Profile defaults to Dark Mode', (tester) async {
      await pumpShell(tester);
      await openProfile(tester);

      expect(themeCubit.state, ThemeMode.dark);

      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
    testWidgets('Profile allows selecting Light Mode', (tester) async {
      await pumpShell(tester);
      await openProfile(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.light);

      final repository = ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      );

      expect(await repository.load(), ThemeMode.light);
    });
    testWidgets('Profile allows selecting System Mode', (tester) async {
      await pumpShell(tester);
      await openProfile(tester);

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.system);

      final repository = ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      );

      expect(await repository.load(), ThemeMode.system);
    });
    testWidgets('Profile supports switching between all theme modes', (
      tester,
    ) async {
      await pumpShell(tester);
      await openProfile(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.light);

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.dark);

      final repository = ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      );

      expect(await repository.load(), ThemeMode.dark);
    });
    testWidgets('Theme preference survives a new ThemeCubit instance', (
      tester,
    ) async {
      await pumpShell(tester);
      await openProfile(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeCubit.state, ThemeMode.light);

      final restoredCubit = ThemeCubit(
        repository: ThemePreferenceRepository(
          preferences: SharedPreferencesAsync(),
        ),
      );

      addTearDown(restoredCubit.close);

      await restoredCubit.initialize();

      expect(restoredCubit.state, ThemeMode.light);
    });
    testWidgets('Selecting Light Mode updates the application theme', (
      tester,
    ) async {
      await pumpShell(tester);
      await openProfile(tester);

      final profileContext = tester.element(find.text('Appearance'));

      expect(Theme.of(profileContext).brightness, Brightness.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      final updatedContext = tester.element(find.text('Appearance'));

      expect(Theme.of(updatedContext).brightness, Brightness.light);

      expect(themeCubit.state, ThemeMode.light);
    });
    testWidgets('Explore displays the country overview', (tester) async {
      await pumpShell(tester);

      expect(find.text('Explore'), findsWidgets);
      expect(find.text('Countries visited'), findsOneWidget);
      expect(find.text('Total visits'), findsOneWidget);
      expect(find.text('No countries visited yet'), findsOneWidget);
    });
  });
}
