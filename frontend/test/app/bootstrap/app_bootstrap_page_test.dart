import 'package:beenaround/app/bootstrap/app_bootstrap_cubit.dart';
import 'package:beenaround/app/bootstrap/app_bootstrap_page.dart';
import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/config/server_config_repository.dart';
import 'package:beenaround/core/network/server_probe.dart';
import 'package:beenaround/core/network/server_probe_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServerConfigRepository implements ServerConfigRepository {
  @override
  Future<ServerConfig?> load() async => null;

  @override
  Future<void> save(ServerConfig config) async {}

  @override
  Future<void> clear() async {}
}

class FakeServerProbe implements ServerConnectivityProbe {
  FakeServerProbe(this.result);

  final ServerProbeResult result;

  @override
  Future<ServerProbeResult> check() async => result;
}

void main() {
  final repository = FakeServerConfigRepository();
  final serverConfig = ServerConfig.parse('https://travel.example.com')!;

  Future<void> pumpBootstrap(
    WidgetTester tester, {
    required ThemeData theme,
    required AppBootstrapCubit cubit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider.value(
          value: cubit,
          child: AppBootstrapPage(
            repository: repository,
            probeFactory: (_) => FakeServerProbe(
              const ServerProbeResult(status: ServerProbeStatus.unavailable),
            ),
            isWeb: true,
          ),
        ),
      ),
    );

    await tester.pump();
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    final isDark = theme.brightness == Brightness.dark;
    final name = isDark ? 'Dark' : 'Light';

    group('$name Mode', () {
      testWidgets('loading uses theme background and progress color', (
        tester,
      ) async {
        final cubit = AppBootstrapCubit(
          repository: repository,
          probeFactory: (_) => FakeServerProbe(
            const ServerProbeResult(status: ServerProbeStatus.unavailable),
          ),
          webServerConfig: serverConfig,
          isWeb: true,
        );

        addTearDown(cubit.close);

        await pumpBootstrap(tester, theme: theme, cubit: cubit);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        expect(scaffold.backgroundColor, isNull);
        expect(progress.color, isNull);
      });

      testWidgets('unavailable server uses semantic theme colors', (
        tester,
      ) async {
        final cubit = AppBootstrapCubit(
          repository: repository,
          probeFactory: (_) => FakeServerProbe(
            const ServerProbeResult(status: ServerProbeStatus.unavailable),
          ),
          webServerConfig: serverConfig,
          isWeb: true,
        );

        addTearDown(cubit.close);

        await cubit.initialize();

        await pumpBootstrap(tester, theme: theme, cubit: cubit);

        expect(find.text('Server unavailable'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Change Server'), findsNothing);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_outlined));

        expect(scaffold.backgroundColor, isNull);
        expect(icon.color, theme.colorScheme.primary);
      });

      testWidgets('incompatible server displays appropriate message', (
        tester,
      ) async {
        final cubit = AppBootstrapCubit(
          repository: repository,
          probeFactory: (_) => FakeServerProbe(
            const ServerProbeResult(status: ServerProbeStatus.incompatible),
          ),
          webServerConfig: serverConfig,
          isWeb: true,
        );

        addTearDown(cubit.close);

        await cubit.initialize();

        await pumpBootstrap(tester, theme: theme, cubit: cubit);

        expect(find.text('Incompatible server'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
      });
    });
  }
}
