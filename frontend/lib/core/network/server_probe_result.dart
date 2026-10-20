enum ServerProbeStatus { ready, setupRequired, incompatible, unavailable }

class ServerProbeResult {
  const ServerProbeResult({required this.status});

  final ServerProbeStatus status;

  bool get isCompatible =>
      status == ServerProbeStatus.ready ||
      status == ServerProbeStatus.setupRequired;
}
