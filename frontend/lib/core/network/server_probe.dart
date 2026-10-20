import 'package:dio/dio.dart';

import 'api_client.dart';
import 'server_probe_result.dart';

class ServerProbe {
  const ServerProbe({required this._apiClient});

  final ApiClient _apiClient;

  Future<ServerProbeResult> check() async {
    try {
      final healthResponse = await _apiClient.dio.get<Object?>('health');

      if (!_isValidHealthResponse(healthResponse.data)) {
        return const ServerProbeResult(status: ServerProbeStatus.incompatible);
      }

      final setupResponse = await _apiClient.dio.get<Object?>('setup/status');

      final setupRequired = _parseSetupRequired(setupResponse.data);

      if (setupRequired == null) {
        return const ServerProbeResult(status: ServerProbeStatus.incompatible);
      }

      return ServerProbeResult(
        status: setupRequired
            ? ServerProbeStatus.setupRequired
            : ServerProbeStatus.ready,
      );
    } on DioException catch (exception) {
      return ServerProbeResult(status: _mapDioError(exception));
    } on FormatException {
      return const ServerProbeResult(status: ServerProbeStatus.incompatible);
    }
  }

  bool _isValidHealthResponse(Object? data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }

    return data['status'] == 'healthy';
  }

  bool? _parseSetupRequired(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final value = data['setup_required'];

    if (value is! bool) {
      return null;
    }

    return value;
  }

  ServerProbeStatus _mapDioError(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return ServerProbeStatus.unavailable;

      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;

        if (statusCode != null && statusCode >= 500) {
          return ServerProbeStatus.unavailable;
        }

        return ServerProbeStatus.incompatible;

      case DioExceptionType.badCertificate:
        return ServerProbeStatus.unavailable;

      case DioExceptionType.unknown:
        if (_containsFormatException(exception.error)) {
          return ServerProbeStatus.incompatible;
        }

        return ServerProbeStatus.unavailable;
      case DioExceptionType.transformTimeout:
        throw UnimplementedError();
    }
  }

  bool _containsFormatException(Object? error) {
    return error is FormatException;
  }
}
