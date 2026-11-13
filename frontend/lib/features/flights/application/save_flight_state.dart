import '../domain/flight.dart';

enum SaveFlightPhase { initial, saving, success, failure }

class SaveFlightState {
  const SaveFlightState({
    this.phase = SaveFlightPhase.initial,
    this.flight,
    this.errorMessage,
  });

  final SaveFlightPhase phase;
  final Flight? flight;
  final String? errorMessage;

  bool get isSaving => phase == SaveFlightPhase.saving;

  bool get isSuccess => phase == SaveFlightPhase.success;

  bool get hasError => phase == SaveFlightPhase.failure;
}
