import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class FirstRunSetupRequest {
  const FirstRunSetupRequest({
    required this.displayName,
    required this.username,
    required this.password,
    this.email,
  });

  final String displayName;
  final String username;
  final String password;
  final String? email;

  Map<String, dynamic> toJson() => {
    'display_name': displayName.trim(),
    'username': username.trim().toLowerCase(),
    'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
    'password': password,
  };
}

enum FirstRunSetupFailure {
  alreadyCompleted,
  validation,
  unavailable,
  unexpected,
}

class FirstRunSetupException implements Exception {
  const FirstRunSetupException(this.failure);

  final FirstRunSetupFailure failure;
}

abstract interface class FirstRunSetupRepository {
  Future<void> createAdministrator(FirstRunSetupRequest request);
}

class ApiFirstRunSetupRepository implements FirstRunSetupRepository {
  const ApiFirstRunSetupRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<void> createAdministrator(FirstRunSetupRequest request) async {
    try {
      await apiClient.dio.post<Map<String, dynamic>>(
        'setup',
        data: request.toJson(),
      );
    } on DioException catch (error) {
      switch (error.response?.statusCode) {
        case 409:
          throw const FirstRunSetupException(
            FirstRunSetupFailure.alreadyCompleted,
          );
        case 422:
          throw const FirstRunSetupException(FirstRunSetupFailure.validation);
        default:
          if (error.response == null) {
            throw const FirstRunSetupException(
              FirstRunSetupFailure.unavailable,
            );
          }

          throw const FirstRunSetupException(FirstRunSetupFailure.unexpected);
      }
    }
  }
}
