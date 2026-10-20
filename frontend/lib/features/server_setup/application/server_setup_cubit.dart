import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_repository.dart';
import '../../../core/network/server_probe.dart';
import '../../../core/network/server_probe_result.dart';
import 'server_setup_state.dart';

typedef ServerProbeFactory =
    ServerConnectivityProbe Function(ServerConfig config);

class ServerSetupCubit extends Cubit<ServerSetupState> {
  ServerSetupCubit({required this._repository, required this._probeFactory})
    : super(const ServerSetupState());

  final ServerConfigRepository _repository;
  final ServerProbeFactory _probeFactory;

  int _requestGeneration = 0;

  void addressChanged(String address) {
    _requestGeneration++;

    emit(ServerSetupState(address: address));
  }

  Future<void> testConnection() async {
    if (state.isChecking || state.isSaving) {
      return;
    }

    final config = ServerConfig.parse(state.address);

    if (config == null) {
      emit(ServerSetupState(address: state.address));
      return;
    }

    final generation = ++_requestGeneration;
    final address = state.address;

    emit(ServerSetupState(address: address, phase: ServerSetupPhase.checking));

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
      ServerProbeStatus.ready ||
      ServerProbeStatus.setupRequired => ServerSetupPhase.available,
      ServerProbeStatus.unavailable => ServerSetupPhase.unavailable,
      ServerProbeStatus.incompatible => ServerSetupPhase.incompatible,
    };

    emit(
      ServerSetupState(
        address: address,
        phase: phase,
        config: result.isCompatible ? config : null,
        probeStatus: result.status,
      ),
    );
  }

  Future<void> connect() async {
    if (!state.canConnect) {
      return;
    }

    final config = state.config!;
    final address = state.address;
    final probeStatus = state.probeStatus!;
    final generation = ++_requestGeneration;

    emit(
      ServerSetupState(
        address: address,
        phase: ServerSetupPhase.saving,
        config: config,
        probeStatus: probeStatus,
      ),
    );

    try {
      await _repository.save(config);
    } catch (_) {
      if (!isClosed && generation == _requestGeneration) {
        emit(
          ServerSetupState(
            address: address,
            phase: ServerSetupPhase.saveFailed,
          ),
        );
      }
      return;
    }

    if (isClosed || generation != _requestGeneration) {
      return;
    }

    emit(
      ServerSetupState(
        address: address,
        phase: ServerSetupPhase.connected,
        config: config,
        probeStatus: probeStatus,
      ),
    );
  }
}
