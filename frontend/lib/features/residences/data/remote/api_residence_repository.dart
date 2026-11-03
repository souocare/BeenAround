import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/residence.dart';
import '../../domain/residence_changes.dart';
import '../../domain/residence_input.dart';
import '../../domain/residence_overlap.dart';
import '../../domain/residence_repository.dart';

/// Authenticated REST implementation of historical residences.
class ApiResidenceRepository implements ResidenceRepository {
  const ApiResidenceRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Residence>> getResidences() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'residences',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing residences response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid residences response.');
      }

      return List.unmodifiable(
        items.map(
          (item) => Residence.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Residence> getResidence({required String residenceId}) async {
    final id = _validatedResidenceId(residenceId);

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'residences/$id',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing residence response.');
      }

      return Residence.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  }) async {
    final payload = <String, dynamic>{...input.toJson()};

    if (overlapConfirmation != null) {
      if (!overlapConfirmation.isCreate) {
        throw ArgumentError(
          'A creation request requires a creation overlap proposal.',
        );
      }

      payload['overlap_confirmation'] = overlapConfirmation
          .toConfirmationJson();
    }

    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'residences',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing residence creation response.');
      }

      return Residence.fromJson(data);
    } on DioException catch (error) {
      throw _mapResidenceError(error);
    }
  }

  @override
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  }) async {
    final id = _validatedResidenceId(residenceId);

    final payload = <String, dynamic>{...changes.toJson()};

    if (overlapConfirmation != null) {
      if (!changes.changesLocationOrDates) {
        throw ArgumentError(
          'Overlap confirmation requires destination or date changes.',
        );
      }

      final expectedTarget = overlapConfirmation.expectedTarget;

      if (expectedTarget == null) {
        throw ArgumentError(
          'An update requires an overlap proposal with an expected target.',
        );
      }

      if (expectedTarget.residenceId != residenceId.trim()) {
        throw ArgumentError(
          'Overlap confirmation does not match the edited residence.',
        );
      }

      payload['overlap_confirmation'] = overlapConfirmation
          .toConfirmationJson();
    }

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'residences/$id',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing residence update response.');
      }

      return Residence.fromJson(data);
    } on DioException catch (error) {
      throw _mapResidenceError(error);
    }
  }

  @override
  Future<void> deleteResidence({required String residenceId}) async {
    final id = _validatedResidenceId(residenceId);

    try {
      await apiClient.dio.delete<void>('residences/$id');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  static String _validatedResidenceId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'residenceId',
        'Expected a non-empty residence ID.',
      );
    }

    return Uri.encodeComponent(normalized);
  }
}

/// Translate residence-specific HTTP conflicts into typed exceptions.
///
/// Authentication, network errors and unrelated HTTP failures continue
/// through the central ApiErrorMapper.
Exception _mapResidenceError(DioException error) {
  final response = error.response;

  if (response?.statusCode == 409) {
    final data = response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is Map) {
        final code = detail['code'];

        if (code == 'RESIDENCE_PERIOD_OVERLAP') {
          try {
            final proposal = ResidenceOverlapProposal.fromJson(
              Map<String, dynamic>.from(detail),
            );

            return ResidenceOverlapRequired(proposal);
          } on FormatException {
            // An invalid proposal must never be offered for confirmation.
          } on TypeError {
            // Unexpected API data must not crash the confirmation flow.
          }
        }

        if (code == 'RESIDENCE_OVERLAP_CONFIRMATION_STALE') {
          final message = detail['message'];

          return ResidenceOverlapStale(
            message is String && message.isNotEmpty
                ? message
                : 'The residence overlap confirmation is no longer valid.',
          );
        }
      }
    }
  }

  return ApiErrorMapper.fromDioException(error);
}
