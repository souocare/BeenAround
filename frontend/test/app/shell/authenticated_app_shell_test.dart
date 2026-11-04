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
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';

import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';

import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_creation_result.dart';

class FakeCountriesRepository implements CountriesRepository {
  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    throw UnimplementedError(
      'Country visit creation is not used by this test.',
    );
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError(
      'Country visit updates are not used by this test.',
    );
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError(
      'Country visit deletion is not used by this test.',
    );
  }
}

class FakeCityVisitsRepository implements CityVisitsRepository {
  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

class FakeCityRepository implements CityRepository {
  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    return const [];
  }

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    return CitySearchResult(
      items: const [],
      total: 0,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    return const [];
  }
}

class FakeResidenceRepository implements ResidenceRepository {
  @override
  Future<List<Residence>> getResidences() async => const [];

  @override
  Future<Residence> getResidence({required String residenceId}) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteResidence({required String residenceId}) {
    throw UnimplementedError();
  }
}

class FakeWishlistRepository implements WishlistRepository {
  @override
  Future<List<WishlistEntry>> getWishlistEntries() async => const [];

  @override
  Future<WishlistEntry> getWishlistEntry({required String entryId}) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWishlistEntry({required String entryId}) {
    throw UnimplementedError();
  }
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
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CityVisitsRepository>(
            create: (_) => FakeCityVisitsRepository(),
          ),
          RepositoryProvider<CityRepository>(
            create: (_) => FakeCityRepository(),
          ),
          RepositoryProvider<ResidenceRepository>(
            create: (_) => FakeResidenceRepository(),
          ),
          RepositoryProvider<WishlistRepository>(
            create: (_) => FakeWishlistRepository(),
          ),
        ],
        child: MultiBlocProvider(
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
      expect(find.text('BeenAround'), findsNWidgets(2));

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
      expect(find.text('No destinations yet'), findsOneWidget);
    });
    testWidgets('iOS compact layout uses adaptive navigation', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await pumpShell(tester);

      expect(find.byType(AdaptiveScaffold), findsOneWidget);

      final scaffold = tester.widget<AdaptiveScaffold>(
        find.byType(AdaptiveScaffold),
      );

      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(scaffold.bottomNavigationBar!.useNativeBottomBar, isTrue);
      expect(scaffold.bottomNavigationBar!.selectedIndex, 0);

      expect(find.text('Countries visited'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS wide layout keeps desktop navigation', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        await pumpShell(tester, size: const Size(1200, 800));

        expect(find.byType(AdaptiveScaffold), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
