import 'dart:async';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/config/server_config_repository.dart';
import 'package:beenaround/core/network/server_probe.dart';
import 'package:beenaround/core/network/server_probe_result.dart';
import 'package:beenaround/features/server_setup/application/server_setup_cubit.dart';
import 'package:beenaround/features/server_setup/application/server_setup_state.dart';
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

class DelayedServerProbe implements ServerConnectivityProbe {
  DelayedServerProbe(this.completer);

  final Completer<ServerProbeResult> completer;

  @override
  Future<ServerProbeResult> check() => completer.future;
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

  group('ServerSetupCubit', () {
    test('starts with Connect disabled', () {
      expect(cubit.state.phase, ServerSetupPhase.idle);
      expect(cubit.state.canConnect, isFalse);
    });

    test('accepts HTTPS addresses without security warning', () {
      cubit.addressChanged('https://travel.example.com');

      expect(cubit.state.showHttpWarning, isFalse);
      expect(cubit.state.canConnect, isFalse);
    });

    test('allows HTTP with security warning', () {
      cubit.addressChanged('http://192.168.1.100:8000');

      expect(cubit.state.showHttpWarning, isTrue);
      expect(cubit.state.canConnect, isFalse);
    });

    test('enables Connect after successful verification', () async {
      cubit.addressChanged('https://travel.example.com');

      await cubit.testConnection();

      expect(cubit.state.phase, ServerSetupPhase.available);
      expect(cubit.state.canConnect, isTrue);
      expect(repository.saveCount, 0);
    });

    test('saves configuration only when Connect is pressed', () async {
      cubit.addressChanged('https://travel.example.com');

      await cubit.testConnection();
      await cubit.connect();

      expect(repository.saveCount, 1);
      expect(
        repository.savedConfig!.baseUrl.toString(),
        'https://travel.example.com',
      );
      expect(cubit.state.phase, ServerSetupPhase.connected);
    });

    test('changing address invalidates a successful check', () async {
      cubit.addressChanged('https://first.example.com');
      await cubit.testConnection();

      expect(cubit.state.canConnect, isTrue);

      cubit.addressChanged('https://second.example.com');

      expect(cubit.state.phase, ServerSetupPhase.idle);
      expect(cubit.state.canConnect, isFalse);
    });

    test('ignores a stale verification result', () async {
      final completer = Completer<ServerProbeResult>();

      final delayedCubit = ServerSetupCubit(
        repository: repository,
        probeFactory: (_) => DelayedServerProbe(completer),
      );

      try {
        delayedCubit.addressChanged('https://first.example.com');

        final pending = delayedCubit.testConnection();

        delayedCubit.addressChanged('https://second.example.com');

        completer.complete(
          const ServerProbeResult(status: ServerProbeStatus.ready),
        );

        await pending;

        expect(delayedCubit.state.canConnect, isFalse);
        expect(delayedCubit.state.address, 'https://second.example.com');
      } finally {
        await delayedCubit.close();
      }
    });

    test('does not enable Connect for invalid URLs', () async {
      cubit.addressChanged('travel.example.com');

      await cubit.testConnection();

      expect(cubit.state.canConnect, isFalse);
      expect(repository.saveCount, 0);
    });
  });
}
