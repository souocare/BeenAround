import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/airport.dart';
import '../../domain/airport_repository.dart';

/// REST implementation of the shared airport catalog.
class ApiAirportRepository implements AirportRepository {
  const ApiAirportRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
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
    final normalizedCountryCode = countryCode?.trim().toUpperCase();

    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;

    final hasCountryCode =
        normalizedCountryCode != null && normalizedCountryCode.isNotEmpty;

    if (!hasQuery && !hasCountryCode) {
      throw ArgumentError('Either query or countryCode must be provided.');
    }

    if (hasCountryCode &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCountryCode)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Expected an ISO alpha-2 country code.',
      );
    }

    final parameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (hasQuery) 'q': normalizedQuery,
      if (hasCountryCode) 'country_code': normalizedCountryCode,
      if (scheduledOnly) 'scheduled_only': true,
    };

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'airports',
        queryParameters: parameters,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing airport search response.');
      }

      return AirportPage.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Airport> getAirport({required int airportId}) async {
    if (airportId <= 0) {
      throw ArgumentError.value(
        airportId,
        'airportId',
        'Expected a positive airport ID.',
      );
    }

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'airports/$airportId',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing airport response.');
      }

      return Airport.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }
}
