import 'package:dio/dio.dart';

import 'api_exception.dart';

abstract final class ApiErrorMapper {
  static ApiException fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'The server took too long to respond.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.connection,
          message: 'Unable to connect to the server.',
        );

      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;

        if (statusCode == 401) {
          return const ApiException(
            type: ApiErrorType.unauthorized,
            message: 'Authentication is required.',
            statusCode: 401,
          );
        }

        if (statusCode == 403) {
          return const ApiException(
            type: ApiErrorType.forbidden,
            message: 'You do not have permission to perform this action.',
            statusCode: 403,
          );
        }

        if (statusCode == 404) {
          return const ApiException(
            type: ApiErrorType.notFound,
            message: 'The requested resource was not found.',
            statusCode: 404,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            type: ApiErrorType.server,
            message: 'The server encountered an error.',
            statusCode: statusCode,
          );
        }

        return ApiException(
          type: ApiErrorType.unknown,
          message: 'The request could not be completed.',
          statusCode: statusCode,
        );

      default:
        return const ApiException(
          type: ApiErrorType.unknown,
          message: 'An unexpected error occurred.',
        );
    }
  }
}
