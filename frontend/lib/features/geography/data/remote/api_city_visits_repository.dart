import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/city_visit.dart';
import '../../domain/city_visits_repository.dart';

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
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'city-visits',
        data: {
          'city_id': cityId,
          'started_on': _formatDate(startedOn),
          'ended_on': _formatDate(endedOn),
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

    final allowedFields = {'city_id', 'started_on', 'ended_on'};

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
      if (entry.key == 'started_on' || entry.key == 'ended_on') {
        final value = entry.value;

        if (value != null && value is! DateTime) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a DateTime or null.',
          );
        }

        payload[entry.key] = _formatDate(value as DateTime?);
      } else {
        final value = entry.value;

        if (value is! int || value <= 0) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a positive city ID.',
          );
        }

        payload[entry.key] = value;
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

  String? _formatDate(DateTime? date) {
    if (date == null) {
      return null;
    }

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
