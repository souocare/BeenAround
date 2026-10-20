import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/config/server_config_repository.dart';
import 'package:beenaround/core/network/server_probe.dart';
import 'package:beenaround/core/network/server_probe_result.dart';
import 'package:beenaround/features/server_setup/application/server_setup_cubit.dart';
import 'package:beenaround/features/server_setup/presentation/pages/server_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServerConfigRepository implements ServerConfigRepository {
  ServerConfig? savedConfig;
  int saveCount = 0;

  @override
  Future<ServerConfig?> load() async => savedConfig;

  @override
  Future<void> save(ServerConfig config) async {
    savedConfig = config;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    savedConfig = null;
  }
}

class FakeServerProbe implements ServerConnectivityProbe {
  FakeServerProbe(this.result);

  final ServerProbeResult result;

  @override
  Future<ServerProbeResult> check() async => result;
}

void main() {
  late FakeServerConfigRepository repository;
  late ServerSetupCubit cubit;

  setUp(() {
    repository = FakeServerConfigRepository();

    cubit = ServerSetupCubit(
      repository: repository,
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.ready),
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pumpServerSetup(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider.value(value: cubit, child: const ServerSetupPage()),
      ),
    );

    await tester.pump();
  }

  Future<void> tapTestConnection(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Test Connection');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapConnect(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Connect to Server');

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    final mode = theme.brightness == Brightness.dark ? 'Dark' : 'Light';

    group('$mode Mode', () {
      testWidgets('renders server setup using theme colors', (tester) async {
        await pumpServerSetup(tester, theme: theme);

        expect(find.text('BeenAround'), findsOneWidget);
        expect(find.text('Connect to your server'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

        expect(scaffold.backgroundColor, isNull);

        final navigationIcon = tester.widget<Icon>(
          find.byIcon(Icons.navigation_rounded),
        );

        expect(navigationIcon.color, theme.colorScheme.primary);
      });

      testWidgets('Connect is disabled before server verification', (
        tester,
      ) async {
        await pumpServerSetup(tester, theme: theme);

        final connectButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Connect to Server'),
        );

        expect(connectButton.onPressed, isNull);
        expect(repository.saveCount, 0);
      });

      testWidgets('HTTP address displays security warning', (tester) async {
        await pumpServerSetup(tester, theme: theme);

        await tester.enterText(
          find.byType(TextField),
          'http://192.168.1.100:8000',
        );

        await tester.pump();

        expect(find.textContaining('Unencrypted connection'), findsOneWidget);

        final warningIcon = tester.widget<Icon>(
          find.byIcon(Icons.warning_amber_rounded),
        );

        expect(warningIcon.color, theme.colorScheme.tertiary);
      });

      testWidgets('HTTPS address does not display security warning', (
        tester,
      ) async {
        await pumpServerSetup(tester, theme: theme);

        await tester.enterText(
          find.byType(TextField),
          'https://travel.example.com',
        );

        await tester.pump();

        expect(find.textContaining('Unencrypted connection'), findsNothing);
      });

      testWidgets('successful verification enables Connect', (tester) async {
        await pumpServerSetup(tester, theme: theme);

        await tester.enterText(
          find.byType(TextField),
          'https://travel.example.com',
        );

        await tester.pump();

        await tapTestConnection(tester);

        expect(find.text('Server available'), findsOneWidget);

        final connectButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Connect to Server'),
        );

        expect(connectButton.onPressed, isNotNull);
        expect(repository.saveCount, 0);
      });

      testWidgets('Connect persists the verified server', (tester) async {
        await pumpServerSetup(tester, theme: theme);

        await tester.enterText(
          find.byType(TextField),
          'https://travel.example.com',
        );

        await tester.pump();

        await tapTestConnection(tester);

        await tapConnect(tester);

        expect(repository.saveCount, 1);
        expect(
          repository.savedConfig?.baseUrl.toString(),
          'https://travel.example.com',
        );
      });
    });
  }

  group('Connection status', () {
    testWidgets('unavailable server displays an error', (tester) async {
      final unavailableCubit = ServerSetupCubit(
        repository: repository,
        probeFactory: (_) => FakeServerProbe(
          const ServerProbeResult(status: ServerProbeStatus.unavailable),
        ),
      );

      addTearDown(unavailableCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BlocProvider.value(
            value: unavailableCubit,
            child: const ServerSetupPage(),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'https://travel.example.com',
      );

      await tapTestConnection(tester);

      expect(find.text('Unable to reach server'), findsOneWidget);

      final connectButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect to Server'),
      );

      expect(connectButton.onPressed, isNull);
    });

    testWidgets('incompatible server displays an error', (tester) async {
      final incompatibleCubit = ServerSetupCubit(
        repository: repository,
        probeFactory: (_) => FakeServerProbe(
          const ServerProbeResult(status: ServerProbeStatus.incompatible),
        ),
      );

      addTearDown(incompatibleCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BlocProvider.value(
            value: incompatibleCubit,
            child: const ServerSetupPage(),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'https://travel.example.com',
      );

      await tapTestConnection(tester);

      expect(find.text('Incompatible server'), findsOneWidget);
    });
  });
}
