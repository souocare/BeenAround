import 'package:beenaround/core/network/api_error_mapper.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final requestOptions = RequestOptions(path: '/test');

  DioException exceptionForStatus(int statusCode) {
    return DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
      ),
    );
  }

  group('ApiErrorMapper', () {
    test('maps connection errors', () {
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );

      final result = ApiErrorMapper.fromDioException(exception);

      expect(result.type, ApiErrorType.connection);
    });

    test('maps timeouts', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final exception = DioException(
          requestOptions: requestOptions,
          type: type,
        );

        final result = ApiErrorMapper.fromDioException(exception);

        expect(result.type, ApiErrorType.timeout);
      }
    });

    test('maps unauthorized responses', () {
      final result = ApiErrorMapper.fromDioException(exceptionForStatus(401));

      expect(result.type, ApiErrorType.unauthorized);
      expect(result.statusCode, 401);
    });

    test('maps forbidden responses', () {
      final result = ApiErrorMapper.fromDioException(exceptionForStatus(403));

      expect(result.type, ApiErrorType.forbidden);
    });

    test('maps not found responses', () {
      final result = ApiErrorMapper.fromDioException(exceptionForStatus(404));

      expect(result.type, ApiErrorType.notFound);
    });

    test('maps all 5xx responses to server errors', () {
      for (final statusCode in [500, 502, 503, 504]) {
        final result = ApiErrorMapper.fromDioException(
          exceptionForStatus(statusCode),
        );

        expect(result.type, ApiErrorType.server);
        expect(result.statusCode, statusCode);
      }
    });

    test('maps unexpected status codes', () {
      final result = ApiErrorMapper.fromDioException(exceptionForStatus(422));

      expect(result.type, ApiErrorType.unknown);
      expect(result.statusCode, 422);
    });

    test('maps unexpected Dio errors', () {
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.unknown,
      );

      final result = ApiErrorMapper.fromDioException(exception);

      expect(result.type, ApiErrorType.unknown);
    });
    test('maps a response without status code to unknown', () {
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: requestOptions),
      );

      final result = ApiErrorMapper.fromDioException(exception);

      expect(result.type, ApiErrorType.unknown);
      expect(result.statusCode, isNull);
    });
  });
}
