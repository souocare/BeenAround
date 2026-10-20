import '../../core/config/server_config.dart';

enum AppBootstrapPhase {
  initial,
  loading,
  serverSetup,
  checking,
  firstRunSetup,
  authentication,
  unavailable,
  incompatible,
}

class AppBootstrapState {
  const AppBootstrapState({required this.phase, this.serverConfig});

  const AppBootstrapState.initial()
    : phase = AppBootstrapPhase.initial,
      serverConfig = null;

  final AppBootstrapPhase phase;
  final ServerConfig? serverConfig;
}
