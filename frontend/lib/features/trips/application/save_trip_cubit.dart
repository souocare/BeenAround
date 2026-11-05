import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/trip_input.dart';
import '../domain/trip_repository.dart';

import 'save_trip_state.dart';

/// Coordinates Trip creation and editing.
///
/// Validation belongs to TripInput.
/// Persistence belongs to TripRepository.
/// This Cubit manages the asynchronous operation and its UI state.
class SaveTripCubit extends Cubit<SaveTripState> {
  SaveTripCubit({required TripRepository repository})
    : _repository = repository,
      super(const SaveTripState());

  final TripRepository _repository;

  /// Create a new Trip.
  Future<void> create({required TripInput input}) {
    return _save(input: input);
  }

  /// Update an existing Trip.
  Future<void> update({required String tripId, required TripInput input}) {
    return _save(input: input, tripId: tripId);
  }

  Future<void> _save({required TripInput input, String? tripId}) async {
    if (isClosed || state.isSubmitting) {
      return;
    }

    // Validate the complete editable representation before
    // starting the persistence operation.
    //
    // The repository also validates before sending HTTP,
    // providing a second defensive boundary.
    try {
      input.toJson();
    } on ArgumentError catch (error) {
      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: _validationMessage(error),
        ),
      );
      return;
    }

    if (tripId != null && tripId.trim().isEmpty) {
      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Invalid Trip identifier.',
        ),
      );
      return;
    }

    emit(const SaveTripState(phase: SaveTripPhase.submitting));

    try {
      final trip = tripId == null
          ? await _repository.createTrip(input: input)
          : await _repository.updateTrip(tripId: tripId, input: input);

      if (isClosed) return;

      emit(SaveTripState(phase: SaveTripPhase.success, trip: trip));
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: error.message,
        ),
      );
    } on ArgumentError catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: _validationMessage(error),
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Unable to save your Trip. Please try again.',
        ),
      );
    }
  }

  static String _validationMessage(ArgumentError error) {
    final message = error.message;

    if (message is String && message.isNotEmpty) {
      return message;
    }

    return 'Please check the Trip information.';
  }
}
