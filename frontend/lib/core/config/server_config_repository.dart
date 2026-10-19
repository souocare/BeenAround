import 'server_config.dart';

abstract interface class ServerConfigRepository {
  Future<ServerConfig?> load();

  Future<void> save(ServerConfig config);

  Future<void> clear();
}
