import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/city.dart';
import '../../domain/city_repository.dart';
import '../../domain/city_search_result.dart';
import '../../domain/city_sort.dart';
import '../../domain/country_city_count.dart';

class ApiCityRepository implements CityRepository {
  const ApiCityRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedQuery = query?.trim();
    final normalizedCountryCode = countryCode?.trim().toUpperCase();

    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }

    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must not be negative.');
    }

    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;

    final hasCountryCode =
        normalizedCountryCode != null && normalizedCountryCode.isNotEmpty;

    if (!hasQuery && !hasCountryCode) {
      throw ArgumentError('Either query or countryCode must be provided.');
    }

    final queryParameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort.name,
    };

    if (hasQuery) {
      queryParameters['q'] = normalizedQuery;
    }

    if (hasCountryCode) {
      queryParameters['country_code'] = normalizedCountryCode;
    }

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'cities',
        queryParameters: queryParameters,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing cities response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid cities response.');
      }

      final total = data['total'];
      final responseLimit = data['limit'];
      final responseOffset = data['offset'];

      if (total is! int || responseLimit is! int || responseOffset is! int) {
        throw const FormatException('Invalid cities pagination metadata.');
      }

      final cities = items
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid city item.');
            }

            final json = Map<String, dynamic>.from(item);

            return _cityFromJson(json);
          })
          .toList(growable: false);

      return CitySearchResult(
        items: cities,
        total: total,
        limit: responseLimit,
        offset: responseOffset,
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'cities/countries',
      );

      final data = response.data;

      if (data == null || data['items'] is! List) {
        throw const FormatException('Invalid country city counts response.');
      }

      final items = data['items'] as List;

      return items
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid country city count item.');
            }

            final json = Map<String, dynamic>.from(item);

            return CountryCityCount(
              countryCode: json['country_code'] as String,
              countryName: json['country_name'] as String,
              cityCount: json['city_count'] as int,
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  City _cityFromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as int,
      name: json['name'] as String,
      asciiName: json['ascii_name'] as String?,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      population: json['population'] as int?,
      featureCode: json['feature_code'] as String,
    );
  }
}
