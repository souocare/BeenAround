import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/flight_input.dart';
import '../domain/flight_repository.dart';
import 'save_flight_state.dart';

/// Handles the creation of independent personal flight records.
class SaveFlightCubit extends Cubit<SaveFlightState> {
  SaveFlightCubit({required FlightRepository repository})
    : _repository = repository,
      super(const SaveFlightState());

  final FlightRepository _repository;

  Future<bool> save(FlightCreateInput input) async {
    if (isClosed || state.isSaving) {
      return false;
    }

    emit(const SaveFlightState(phase: SaveFlightPhase.saving));

    try {
      final flight = await _repository.createFlight(input: input);

      if (isClosed) return false;

      emit(SaveFlightState(phase: SaveFlightPhase.success, flight: flight));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        SaveFlightState(
          phase: SaveFlightPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const SaveFlightState(
          phase: SaveFlightPhase.failure,
          errorMessage: 'Unable to save your flight.',
        ),
      );

      return false;
    }
  }

  void reset() {
    if (isClosed || state.isSaving) return;

    emit(const SaveFlightState());
  }
}
