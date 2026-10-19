import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';
import 'server_config_repository.dart';

class LocalServerConfigRepository implements ServerConfigRepository {
  LocalServerConfigRepository({
    required this._preferences,
    this.allowHttp = false,
  });

  static const String storageKey = 'beenaround.server_url';

  final SharedPreferencesAsync _preferences;
  final bool allowHttp;

  @override
  Future<ServerConfig?> load() async {
    final storedUrl = await _preferences.getString(storageKey);

    if (storedUrl == null) {
      return null;
    }

    return ServerConfig.parse(storedUrl, allowHttp: allowHttp);
  }

  @override
  Future<void> save(ServerConfig config) async {
    if (config.baseUrl.scheme == 'http' && !allowHttp) {
      throw ArgumentError.value(
        config.baseUrl,
        'config',
        'HTTP server URLs are not allowed.',
      );
    }

    await _preferences.setString(storageKey, config.baseUrl.toString());
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(storageKey);
  }
}
