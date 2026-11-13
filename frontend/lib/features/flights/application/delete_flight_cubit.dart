import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/flight_repository.dart';

import 'delete_flight_state.dart';

/// Deletes one authenticated user's personal flight.
///
/// Ownership and authorization are enforced by the backend.
///
/// Deleting a flight does not delete visits or Trips.
class DeleteFlightCubit extends Cubit<DeleteFlightState> {
  DeleteFlightCubit({required FlightRepository repository})
    : _repository = repository,
      super(const DeleteFlightState());

  final FlightRepository _repository;

  Future<bool> deleteFlight(String flightId) async {
    if (isClosed || state.isDeleting || state.isSuccess) {
      return false;
    }

    emit(const DeleteFlightState(phase: DeleteFlightPhase.deleting));

    try {
      await _repository.deleteFlight(flightId: flightId);

      if (isClosed) return false;

      emit(const DeleteFlightState(phase: DeleteFlightPhase.success));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        DeleteFlightState(
          phase: DeleteFlightPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const DeleteFlightState(
          phase: DeleteFlightPhase.failure,
          errorMessage: 'Unable to delete your flight.',
        ),
      );

      return false;
    }
  }
}
