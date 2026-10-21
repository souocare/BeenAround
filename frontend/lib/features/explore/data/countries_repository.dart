import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/country.dart';
import '../domain/country_visit.dart';

abstract interface class CountriesRepository {
  Future<List<Country>> getCountries();

  Future<List<CountryVisit>> getCountryVisits();

  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  });
}

class ApiCountriesRepository implements CountriesRepository {
  const ApiCountriesRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Country>> getCountries() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'countries',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing countries response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid countries response.');
      }

      return items
          .map(
            (item) => Country.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'country-visits',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing country visits response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid country visits response.');
      }

      return items
          .map(
            (item) =>
                CountryVisit.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'country-visits',
        data: {
          'country_code': countryCode.trim().toUpperCase(),
          'started_on': _formatDate(startedOn),
          'ended_on': _formatDate(endedOn),
        },
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing country visit creation response.');
      }

      return CountryVisit.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
