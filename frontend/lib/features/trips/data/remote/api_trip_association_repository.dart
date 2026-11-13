import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../../explore/domain/country_visit.dart';
import '../../../geography/domain/city_visit.dart';

import '../../domain/trip_association_repository.dart';
import '../../../flights/domain/flight.dart';

/// Authenticated REST implementation of TripAssociationRepository.
///
/// Association operations never create or delete the original visits.
class ApiTripAssociationRepository implements TripAssociationRepository {
  const ApiTripAssociationRepository({required this.apiClient});

  final ApiClient apiClient;

  // ---------------------------------------------------------
  // Country visits
  // ---------------------------------------------------------

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) async {
    final id = _validatedId(tripId, 'tripId');

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'trips/$id/country-visits',
      );

      return _parseAssociationList(
        response.data,
        description: 'Trip country visits',
        parser: CountryVisit.fromJson,
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    _validatedId(visitId, 'visitId');

    try {
      await apiClient.dio.post<Map<String, dynamic>>(
        'trips/$id/country-visits',
        data: {'country_visit_id': visitId.trim()},
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> removeCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    final visit = _validatedId(visitId, 'visitId');

    try {
      await apiClient.dio.delete<void>('trips/$id/country-visits/$visit');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  // ---------------------------------------------------------
  // City visits
  // ---------------------------------------------------------

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) async {
    final id = _validatedId(tripId, 'tripId');

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'trips/$id/city-visits',
      );

      return _parseAssociationList(
        response.data,
        description: 'Trip city visits',
        parser: CityVisit.fromJson,
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> addCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    _validatedId(visitId, 'visitId');

    try {
      await apiClient.dio.post<Map<String, dynamic>>(
        'trips/$id/city-visits',
        data: {'city_visit_id': visitId.trim()},
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> removeCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    final visit = _validatedId(visitId, 'visitId');

    try {
      await apiClient.dio.delete<void>('trips/$id/city-visits/$visit');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  // ---------------------------------------------------------
  // Flights
  // ---------------------------------------------------------

  @override
  Future<List<Flight>> getFlights({required String tripId}) async {
    final id = _validatedId(tripId, 'tripId');

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'trips/$id/flights',
      );

      return _parseAssociationList(
        response.data,
        description: 'Trip flights',
        parser: Flight.fromJson,
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> addFlight({
    required String tripId,
    required String flightId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    final flight = flightId.trim();

    _validatedId(flight, 'flightId');

    try {
      await apiClient.dio.post<Map<String, dynamic>>(
        'trips/$id/flights',
        data: {'flight_id': flight},
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> removeFlight({
    required String tripId,
    required String flightId,
  }) async {
    final id = _validatedId(tripId, 'tripId');
    final flight = _validatedId(flightId, 'flightId');

    try {
      await apiClient.dio.delete<void>('trips/$id/flights/$flight');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  // ---------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------

  /// Parse the standard paginated-list envelope used by the API.
  ///
  /// The backend currently returns all Trip associations without
  /// pagination, using the same {items, total} structure as Explore.
  /// Parse the {items, total} association-list response.
  static List<T> _parseAssociationList<T>(
    Map<String, dynamic>? data, {
    required String description,
    required T Function(Map<String, dynamic>) parser,
  }) {
    if (data == null) {
      throw FormatException('Missing $description response.');
    }

    final items = data['items'];

    if (items is! List) {
      throw FormatException('Invalid $description response.');
    }

    return List.unmodifiable(
      items.map((item) => parser(Map<String, dynamic>.from(item as Map))),
    );
  }

  /// Validate identifiers before constructing request paths.
  ///
  /// Uses the same non-empty identifier policy as ApiTripRepository.
  static String _validatedId(String value, String parameter) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        parameter,
        'Expected a non-empty identifier.',
      );
    }

    return Uri.encodeComponent(normalized);
  }
}
