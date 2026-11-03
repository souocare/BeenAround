import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error_mapper.dart';

import '../../domain/wishlist_creation_result.dart';
import '../../domain/wishlist_entry.dart';
import '../../domain/wishlist_entry_input.dart';
import '../../domain/wishlist_repository.dart';

/// Authenticated REST implementation of the global wishlist.
class ApiWishlistRepository implements WishlistRepository {
  const ApiWishlistRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<WishlistEntry>> getWishlistEntries() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'wishlist',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing wishlist response.');
      }

      final items = data['items'];

      if (items is! List) {
        throw const FormatException('Invalid wishlist response.');
      }

      return List.unmodifiable(
        items.map(
          (item) =>
              WishlistEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<WishlistEntry> getWishlistEntry({required String entryId}) async {
    final id = _validatedEntryId(entryId);

    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        'wishlist/$id',
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing wishlist entry response.');
      }

      return WishlistEntry.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<WishlistCreationResult> addWishlistEntry({
    required WishlistEntryInput input,
  }) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'wishlist',
        data: input.toJson(),
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing wishlist creation response.');
      }

      return WishlistCreationResult.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<WishlistEntry> updateWishlistNote({
    required String entryId,
    required String? note,
  }) async {
    final id = _validatedEntryId(entryId);

    // The PATCH contract requires the note key to be present.
    // Sending null explicitly clears the note.
    final normalizedNote = _normalizeNote(note);

    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        'wishlist/$id',
        data: {'note': normalizedNote},
      );

      final data = response.data;

      if (data == null) {
        throw const FormatException('Missing wishlist update response.');
      }

      return WishlistEntry.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  @override
  Future<void> deleteWishlistEntry({required String entryId}) async {
    final id = _validatedEntryId(entryId);

    try {
      await apiClient.dio.delete<void>('wishlist/$id');
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDioException(error);
    }
  }

  static String _validatedEntryId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'entryId',
        'Expected a non-empty wishlist entry ID.',
      );
    }

    return Uri.encodeComponent(normalized);
  }

  static String? _normalizeNote(String? value) {
    if (value == null) return null;

    if (value.length > 1000) {
      throw ArgumentError.value(
        value,
        'note',
        'A wishlist note cannot exceed 1000 characters.',
      );
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}
