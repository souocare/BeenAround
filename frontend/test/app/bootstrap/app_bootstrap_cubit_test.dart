import 'package:beenaround/app/bootstrap/app_bootstrap_cubit.dart';
import 'package:beenaround/app/bootstrap/app_bootstrap_state.dart';
import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/config/server_config_repository.dart';
import 'package:beenaround/core/network/server_probe.dart';
import 'package:beenaround/core/network/server_probe_result.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServerConfigRepository implements ServerConfigRepository {
  FakeServerConfigRepository({this.stored});

  ServerConfig? stored;
  int loadCount = 0;

  @override
  Future<ServerConfig?> load() async {
    loadCount++;
    return stored;
  }

  @override
  Future<void> save(ServerConfig config) async {
    stored = config;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class FakeServerProbe implements ServerConnectivityProbe {
  FakeServerProbe(this.result);

  final ServerProbeResult result;

  @override
  Future<ServerProbeResult> check() async => result;
}

void main() {
  final server = ServerConfig.parse('https://travel.example.com')!;

  test('shows server setup when no server is configured', () async {
    final repository = FakeServerConfigRepository();

    final cubit = AppBootstrapCubit(
      repository: repository,
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.ready),
      ),
      webServerConfig: null,
      isWeb: false,
    );

    await cubit.initialize();

    expect(cubit.state.phase, AppBootstrapPhase.serverSetup);

    await cubit.close();
  });

  test('routes to first-run setup when setup is required', () async {
    final cubit = AppBootstrapCubit(
      repository: FakeServerConfigRepository(stored: server),
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.setupRequired),
      ),
      webServerConfig: null,
      isWeb: false,
    );

    await cubit.initialize();

    expect(cubit.state.phase, AppBootstrapPhase.firstRunSetup);
    expect(cubit.state.serverConfig?.baseUrl, server.baseUrl);

    await cubit.close();
  });

  test('routes to login when server is ready', () async {
    final cubit = AppBootstrapCubit(
      repository: FakeServerConfigRepository(stored: server),
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.ready),
      ),
      webServerConfig: null,
      isWeb: false,
    );

    await cubit.initialize();

    expect(cubit.state.phase, AppBootstrapPhase.authentication);

    await cubit.close();
  });

  test('retains server when it is unavailable', () async {
    final repository = FakeServerConfigRepository(stored: server);

    final cubit = AppBootstrapCubit(
      repository: repository,
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.unavailable),
      ),
      webServerConfig: null,
      isWeb: false,
    );

    await cubit.initialize();

    expect(cubit.state.phase, AppBootstrapPhase.unavailable);
    expect(repository.stored?.baseUrl, server.baseUrl);

    await cubit.close();
  });

  test('web configuration takes precedence over stored server', () async {
    final repository = FakeServerConfigRepository();

    final cubit = AppBootstrapCubit(
      repository: repository,
      probeFactory: (_) => FakeServerProbe(
        const ServerProbeResult(status: ServerProbeStatus.ready),
      ),
      webServerConfig: server,
      isWeb: true,
    );

    await cubit.initialize();

    expect(cubit.state.phase, AppBootstrapPhase.authentication);
    expect(repository.loadCount, 0);

    await cubit.close();
  });
}
