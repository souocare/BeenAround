import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/flight.dart';
import '../../domain/flight_detail.dart';
import '../../domain/flight_input.dart';
import '../../domain/flight_repository.dart';

/// Authenticated REST implementation of FlightRepository.
///
/// The backend is the source of truth for flight timing,
/// including timezone offsets and elapsed duration.
class ApiFlightRepository implements FlightRepository {
  const ApiFlightRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }

    if (offset < 0) {
      throw RangeError.range(offset, 0, null, 'offset');
    }

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'flights',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (status != null) 'status': status.apiValue,
        },
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing flights response.');
      }

      return FlightPage.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Flight> getFlight({required String flightId}) async {
    // Reuse the detail endpoint implementation.
    //
    // No duplicate HTTP requests or independent
    // flight response parsing.
    final detail = await getFlightDetail(flightId: flightId);

    return detail.flight;
  }

  @override
  Future<FlightDetail> getFlightDetail({required String flightId}) async {
    final id = _validatedFlightId(flightId);

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'flights/$id',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing flight detail response.');
      }

      return FlightDetail.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Flight> createFlight({required FlightCreateInput input}) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'flights',
        data: input.toJson(),
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing flight creation response.');
      }

      return Flight.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Flight> updateFlight({
    required String flightId,
    required FlightPatch patch,
  }) async {
    final id = _validatedFlightId(flightId);

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'flights/$id',
        data: patch.toJson(),
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing flight update response.');
      }

      return Flight.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> deleteFlight({required String flightId}) async {
    final id = _validatedFlightId(flightId);

    try {
      await apiClient.dio.delete<void>('flights/$id');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  static String _validatedFlightId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'flightId',
        'Expected a non-empty Flight ID.',
      );
    }

    return Uri.encodeComponent(normalized);
  }
}
