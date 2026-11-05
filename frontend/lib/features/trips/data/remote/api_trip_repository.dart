import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';
import '../../domain/trip_input.dart';

/// Authenticated REST implementation of TripRepository.
class ApiTripRepository implements TripRepository {
  const ApiTripRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<Trip>> getTrips() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>('trips');

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing Trips response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid Trips response.');
      }

      return List.unmodifiable(
        items.map(
          (item) => Trip.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Trip> getTrip({required String tripId}) async {
    final id = _validatedTripId(tripId);

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'trips/$id',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing Trip response.');
      }

      return Trip.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Trip> createTrip({required TripInput input}) async {
    final payload = input.toJson();

    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'trips',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing Trip creation response.');
      }

      return Trip.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required TripInput input,
  }) async {
    final id = _validatedTripId(tripId);
    final payload = input.toJson();

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'trips/$id',
        data: payload,
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing Trip update response.');
      }

      return Trip.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> deleteTrip({required String tripId}) async {
    final id = _validatedTripId(tripId);

    try {
      await apiClient.dio.delete<void>('trips/$id');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  static String _validatedTripId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'tripId',
        'Expected a non-empty Trip ID.',
      );
    }

    return Uri.encodeComponent(normalized);
  }
}
