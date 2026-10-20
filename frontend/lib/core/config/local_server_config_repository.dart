import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';
import 'server_config_repository.dart';

class LocalServerConfigRepository implements ServerConfigRepository {
  LocalServerConfigRepository({required this._preferences});

  static const String storageKey = 'beenaround.server_url';

  final SharedPreferencesAsync _preferences;

  @override
  Future<ServerConfig?> load() async {
    final storedUrl = await _preferences.getString(storageKey);

    if (storedUrl == null) {
      return null;
    }

    return ServerConfig.parse(storedUrl);
  }

  @override
  Future<void> save(ServerConfig config) async {
    await _preferences.setString(storageKey, config.baseUrl.toString());
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(storageKey);
  }
}
