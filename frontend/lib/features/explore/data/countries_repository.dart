import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/country.dart';
import '../domain/country_visit.dart';
import '../../../core/models/visit_date_precision.dart';
import '../../../core/models/visit_date_serializer.dart';

abstract interface class CountriesRepository {
  Future<List<Country>> getCountries();

  Future<List<CountryVisit>> getCountryVisits();

  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  });
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  });
  Future<void> deleteCountryVisit({required String visitId});
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
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'country-visits',
        data: {
          'country_code': countryCode.trim().toUpperCase(),
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
        throw const FormatException('Missing country visit creation response.');
      }

      return CountryVisit.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<CountryVisit> updateCountryVisit({
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

    final payload = VisitDateSerializer.updateFields(changes);

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'country-visits/${Uri.encodeComponent(visitId)}',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing country visit update response.');
      }

      return CountryVisit.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) async {
    try {
      await apiClient.dio.delete<void>(
        'country-visits/${Uri.encodeComponent(visitId)}',
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }
}
