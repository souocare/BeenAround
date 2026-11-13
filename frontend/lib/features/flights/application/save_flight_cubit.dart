import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/flight.dart';
import '../domain/flight_input.dart';
import '../domain/flight_repository.dart';

import 'save_flight_state.dart';

/// Handles persistence of independent personal flight records.
///
/// Supports creating new flights and updating existing flights.
///
/// Flights remain independent of visits and Trips.
class SaveFlightCubit extends Cubit<SaveFlightState> {
  SaveFlightCubit({required FlightRepository repository})
    : _repository = repository,
      super(const SaveFlightState());

  final FlightRepository _repository;

  /// Create a new personal flight.
  Future<bool> save(FlightCreateInput input) async {
    if (!_canSubmit) return false;

    emit(const SaveFlightState(phase: SaveFlightPhase.saving));

    try {
      final flight = await _repository.createFlight(input: input);

      return _completeSuccess(flight);
    } on ApiException catch (error) {
      return _completeFailure(error.message);
    } catch (_) {
      return _completeFailure('Unable to save your flight.');
    }
  }

  /// Update an existing user-owned flight.
  ///
  /// The patch contains only explicitly changed fields.
  /// Ownership and final-state validation are enforced
  /// by the backend.
  Future<bool> update({
    required String flightId,
    required FlightPatch patch,
  }) async {
    if (!_canSubmit) return false;

    if (patch.isEmpty) {
      return false;
    }

    emit(const SaveFlightState(phase: SaveFlightPhase.saving));

    try {
      final flight = await _repository.updateFlight(
        flightId: flightId,
        patch: patch,
      );

      return _completeSuccess(flight);
    } on ApiException catch (error) {
      return _completeFailure(error.message);
    } catch (_) {
      return _completeFailure('Unable to update your flight.');
    }
  }

  bool get _canSubmit {
    return !isClosed && !state.isSaving && !state.isSuccess;
  }

  bool _completeSuccess(Flight flight) {
    if (isClosed) return false;

    emit(SaveFlightState(phase: SaveFlightPhase.success, flight: flight));

    return true;
  }

  bool _completeFailure(String message) {
    if (isClosed) return false;

    emit(
      SaveFlightState(phase: SaveFlightPhase.failure, errorMessage: message),
    );

    return false;
  }

  void reset() {
    if (isClosed || state.isSaving) return;

    emit(const SaveFlightState());
  }
}
