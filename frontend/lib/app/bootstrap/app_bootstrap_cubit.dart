import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/server_config.dart';
import '../../core/config/server_config_repository.dart';
import '../../core/network/server_probe.dart';
import '../../core/network/server_probe_result.dart';
import 'app_bootstrap_state.dart';

typedef BootstrapProbeFactory =
    ServerConnectivityProbe Function(ServerConfig config);

class AppBootstrapCubit extends Cubit<AppBootstrapState> {
  AppBootstrapCubit({
    required this._repository,
    required this._probeFactory,
    required this._webServerConfig,
    required this._isWeb,
  }) : super(const AppBootstrapState.initial());

  final ServerConfigRepository _repository;
  final BootstrapProbeFactory _probeFactory;
  final ServerConfig? _webServerConfig;
  final bool _isWeb;

  int _requestGeneration = 0;

  Future<void> initialize() async {
    final generation = ++_requestGeneration;

    emit(const AppBootstrapState(phase: AppBootstrapPhase.loading));

    ServerConfig? config;

    if (_isWeb) {
      config = _webServerConfig;

      if (config == null) {
        if (!isClosed && generation == _requestGeneration) {
          emit(const AppBootstrapState(phase: AppBootstrapPhase.incompatible));
        }
        return;
      }
    } else {
      try {
        config = await _repository.load();
      } catch (_) {
        if (!isClosed && generation == _requestGeneration) {
          emit(const AppBootstrapState(phase: AppBootstrapPhase.unavailable));
        }
        return;
      }
    }

    if (isClosed || generation != _requestGeneration) {
      return;
    }

    if (config == null) {
      emit(const AppBootstrapState(phase: AppBootstrapPhase.serverSetup));
      return;
    }

    emit(
      AppBootstrapState(
        phase: AppBootstrapPhase.checking,
        serverConfig: config,
      ),
    );

    ServerProbeResult result;

    try {
      result = await _probeFactory(config).check();
    } catch (_) {
      result = const ServerProbeResult(status: ServerProbeStatus.unavailable);
    }

    if (isClosed || generation != _requestGeneration) {
      return;
    }

    final phase = switch (result.status) {
      ServerProbeStatus.setupRequired => AppBootstrapPhase.firstRunSetup,
      ServerProbeStatus.ready => AppBootstrapPhase.authentication,
      ServerProbeStatus.unavailable => AppBootstrapPhase.unavailable,
      ServerProbeStatus.incompatible => AppBootstrapPhase.incompatible,
    };

    emit(AppBootstrapState(phase: phase, serverConfig: config));
  }

  Future<void> retry() => initialize();

  Future<void> serverConnected() => initialize();

  void configureDifferentServer() {
    ++_requestGeneration;

    emit(const AppBootstrapState(phase: AppBootstrapPhase.serverSetup));
  }

  void administratorCreated() {
    ++_requestGeneration;

    emit(
      AppBootstrapState(
        phase: AppBootstrapPhase.authentication,
        serverConfig: state.serverConfig,
      ),
    );
  }
}
