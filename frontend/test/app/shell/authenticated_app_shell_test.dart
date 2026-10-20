import 'package:beenaround/app/shell/authenticated_app_shell.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedAppShell(
          user: user,
          onLogout: onLogout ?? () async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  group('AuthenticatedAppShell', () {
    testWidgets('opens Explore by default on mobile', (tester) async {
      await pumpShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.text('Your visited countries, cities and flights.'),
        findsOneWidget,
      );

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

      expect(
        find.text('Your visited countries, cities and flights.'),
        findsOneWidget,
      );
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
      expect(
        find.text('Your visited countries, cities and flights.'),
        findsOneWidget,
      );
    });
  });
}
