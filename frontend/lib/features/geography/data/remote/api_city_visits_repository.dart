import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/city_visit.dart';
import '../../domain/city_visits_repository.dart';
import '../../../../core/models/visit_date_precision.dart';
import '../../../../core/models/visit_date_serializer.dart';

class ApiCityVisitsRepository implements CityVisitsRepository {
  const ApiCityVisitsRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'city-visits',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing city visits response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid city visits response.');
      }

      return items
          .map(
            (item) =>
                CityVisit.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'city-visits',
        data: {
          'city_id': cityId,
          ...VisitDateSerializer.createFields(
            startedOn: startedOn,
            endedOn: endedOn,
            startedOnPrecision: startedOnPrecision,
            endedOnPrecision: endedOnPrecision,
          ),
        },
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing city visit creation response.');
      }

      return CityVisit.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    if (changes.isEmpty) {
      throw ArgumentError.value(
        changes,
        'changes',
        'At least one field must be provided.',
      );
    }

    const allowedFields = {
      'city_id',
      'started_on',
      'ended_on',
      'started_on_precision',
      'ended_on_precision',
    };

    for (final key in changes.keys) {
      if (!allowedFields.contains(key)) {
        throw ArgumentError.value(
          key,
          'changes',
          'Unsupported city visit field.',
        );
      }
    }

    final payload = <String, dynamic>{};

    for (final entry in changes.entries) {
      if (entry.key == 'city_id') {
        final value = entry.value;

        if (value is! int || value <= 0) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a positive city ID.',
          );
        }

        payload[entry.key] = value;
      } else {
        payload.addAll(
          VisitDateSerializer.updateFields({entry.key: entry.value}),
        );
      }
    }

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'city-visits/${Uri.encodeComponent(visitId)}',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing city visit update response.');
      }

      return CityVisit.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) async {
    try {
      await apiClient.dio.delete<void>(
        'city-visits/${Uri.encodeComponent(visitId)}',
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }
}
