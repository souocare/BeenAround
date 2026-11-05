enum ApiErrorType {
  connection,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  unknown,
  conflict,
  validation,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
