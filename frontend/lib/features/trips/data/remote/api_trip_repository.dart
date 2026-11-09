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

  Future<List<Trip>> _getTripList(String path) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(path);

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
  Future<List<Trip>> getTrips() {
    return _getTripList('trips');
  }

  @override
  Future<List<Trip>> getTripsForCountry({required String countryCode}) {
    final code = countryCode.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Expected a valid ISO alpha-2 country code.',
      );
    }

    return _getTripList('countries/$code/trips');
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
