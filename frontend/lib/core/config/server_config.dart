import 'package:flutter/foundation.dart';

class ServerConfig {
  const ServerConfig._(this.baseUrl);

  final Uri baseUrl;

  static ServerConfig? parse(String input, {bool allowHttp = false}) {
    final value = input.trim();

    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    if (uri.scheme == 'http' && !allowHttp) {
      return null;
    }

    // The server URL represents an origin, not an API endpoint.
    if (uri.path.isNotEmpty && uri.path != '/') {
      return null;
    }

    return ServerConfig._(uri.replace(path: '', query: null, fragment: null));
  }

  Uri get apiBaseUrl => baseUrl.replace(path: '/api/v1/');

  static ServerConfig? forWeb() {
    if (!kIsWeb) {
      return null;
    }

    return ServerConfig.parse(Uri.base.origin, allowHttp: true);
  }
}
