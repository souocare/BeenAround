import '../../../core/config/server_config.dart';
import '../../../core/network/server_probe_result.dart';

enum ServerSetupPhase {
  idle,
  checking,
  available,
  unavailable,
  incompatible,
  saving,
  connected,
  saveFailed,
}

class ServerSetupState {
  const ServerSetupState({
    this.address = '',
    this.phase = ServerSetupPhase.idle,
    this.config,
    this.probeStatus,
  });

  final String address;
  final ServerSetupPhase phase;
  final ServerConfig? config;
  final ServerProbeStatus? probeStatus;

  bool get canConnect =>
      phase == ServerSetupPhase.available &&
      config != null &&
      probeStatus != null;

  bool get isChecking => phase == ServerSetupPhase.checking;

  bool get isSaving => phase == ServerSetupPhase.saving;

  bool get showHttpWarning {
    final parsed = ServerConfig.parse(address);
    return parsed != null && !parsed.isSecure;
  }
}
