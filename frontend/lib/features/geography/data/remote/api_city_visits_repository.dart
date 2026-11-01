import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/city_visit.dart';
import '../../domain/city_visits_repository.dart';
import '../../../../core/models/visit_date_precision.dart';
import '../../../../core/models/visit_date_serializer.dart';
import '../../domain/new_country_visit_input.dart';
import '../../domain/country_visit_date_expansion.dart';

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
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    // An existing country visit and a new country visit are mutually exclusive.
    if (countryVisitId != null && newCountryVisit != null) {
      throw ArgumentError(
        'Cannot associate an existing country visit and create a new '
        'country visit in the same request.',
      );
    }

    if (countryVisitId != null && countryVisitId.trim().isEmpty) {
      throw ArgumentError.value(
        countryVisitId,
        'countryVisitId',
        'Expected a non-empty country visit ID.',
      );
    }

    // A date expansion confirmation can only target the selected
    // existing country visit.
    if (countryDateExpansion != null) {
      if (countryVisitId == null || newCountryVisit != null) {
        throw ArgumentError(
          'Country date expansion requires an existing country visit.',
        );
      }

      if (countryDateExpansion.countryVisitId != countryVisitId) {
        throw ArgumentError(
          'Country date expansion does not match the selected country visit.',
        );
      }
    }

    final payload = <String, dynamic>{
      'city_id': cityId,
      ...VisitDateSerializer.createFields(
        startedOn: startedOn,
        endedOn: endedOn,
        startedOnPrecision: startedOnPrecision,
        endedOnPrecision: endedOnPrecision,
      ),
    };

    // Option 1: Associate with an existing country visit.
    if (countryVisitId != null) {
      payload['country_visit_id'] = countryVisitId;
    }

    // Option 2: Explicitly create a new country visit.
    if (newCountryVisit != null) {
      payload['new_country_visit'] = VisitDateSerializer.createFields(
        startedOn: newCountryVisit.startedOn,
        endedOn: newCountryVisit.endedOn,
        startedOnPrecision: newCountryVisit.startedOnPrecision,
        endedOnPrecision: newCountryVisit.endedOnPrecision,
      );
    }

    // Option 3: Apply an explicitly confirmed date expansion.
    // The backend remains responsible for validating the confirmation.
    if (countryDateExpansion != null) {
      payload['country_date_expansion'] = countryDateExpansion
          .toConfirmationJson();
    }

    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'city-visits',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing city visit creation response.');
      }

      return CityVisit.fromJson(data);
    } on DioException catch (error) {
      throw _mapCityVisitError(error);
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
      'country_visit_id',
      'country_date_expansion',
      'started_on',
      'ended_on',
      'started_on_precision',
      'ended_on_precision',
    };

    // Reject unsupported fields before sending an HTTP request.
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
      } else if (entry.key == 'country_visit_id') {
        final value = entry.value;

        // Null explicitly removes the association.
        // An omitted field preserves the existing association.
        if (value != null && (value is! String || value.trim().isEmpty)) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a non-empty country visit ID or null.',
          );
        }

        payload[entry.key] = value;
      } else if (entry.key == 'country_date_expansion') {
        final value = entry.value;

        if (value is! CountryVisitDateExpansion) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a CountryVisitDateExpansion.',
          );
        }

        // Serialize only the exact proposal approved by the user.
        payload[entry.key] = value.toConfirmationJson();
      } else {
        payload.addAll(
          VisitDateSerializer.updateFields({entry.key: entry.value}),
        );
      }
    }

    // If the PATCH explicitly specifies a country visit, its ID must
    // match the country visit referenced by the confirmation.
    //
    // When country_visit_id is omitted, the backend uses the
    // association already stored for this city visit.
    final expansion = changes['country_date_expansion'];

    if (expansion is CountryVisitDateExpansion &&
        changes.containsKey('country_visit_id')) {
      final countryVisitId = changes['country_visit_id'];

      if (countryVisitId != expansion.countryVisitId) {
        throw ArgumentError(
          'Country date expansion does not match the selected country visit.',
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
      throw _mapCityVisitError(error);
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

Exception _mapCityVisitError(DioException error) {
  final response = error.response;

  if (response?.statusCode == 409) {
    final data = response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is Map &&
          detail['code'] == 'COUNTRY_VISIT_DATE_EXPANSION_REQUIRED') {
        try {
          final expansion = CountryVisitDateExpansion.fromJson(
            Map<String, dynamic>.from(detail),
          );

          return CountryVisitDateExpansionRequired(expansion);
        } on FormatException {
          // Malformed expansion payloads fall back to the standard API error.
        } on TypeError {
          // Invalid response types must not crash the UI.
        }
      }
    }
  }

  return ApiErrorMapper.fromDioException(error);
}
