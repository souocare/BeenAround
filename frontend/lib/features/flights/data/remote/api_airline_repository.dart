import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/airline.dart';
import '../../domain/airline_repository.dart';

/// REST implementation of the shared airline catalog.
class ApiAirlineRepository implements AirlineRepository {
  const ApiAirlineRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }

    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must not be negative.');
    }

    final normalizedQuery = query?.trim();

    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'airlines',
        queryParameters: {
          if (hasQuery) 'q': normalizedQuery,
          'limit': limit,
          'offset': offset,
        },
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing airline search response.');
      }

      return AirlinePage.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Airline> getAirline({required int airlineId}) async {
    if (airlineId <= 0) {
      throw ArgumentError.value(
        airlineId,
        'airlineId',
        'Expected a positive airline ID.',
      );
    }

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'airlines/$airlineId',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing airline response.');
      }

      return Airline.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }
}
