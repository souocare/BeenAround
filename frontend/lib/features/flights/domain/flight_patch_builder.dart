import 'flight.dart';
import 'flight_input.dart';

/// Builds an explicit partial update by comparing the edited
/// form values against the persisted flight.
///
/// A missing field means unchanged.
/// A null value means clearing an optional field.
///
/// Returns null when no changes need to be persisted.
abstract final class FlightPatchBuilder {
  static FlightPatch? build({
    required Flight original,
    required FlightCreateInput edited,
  }) {
    final changes = <String, dynamic>{};

    void addIfChanged(
      String field,
      Object? originalValue,
      Object? editedValue,
    ) {
      if (originalValue != editedValue) {
        changes[field] = editedValue;
      }
    }

    // --------------------------------------------------------
    // Route
    // --------------------------------------------------------

    addIfChanged(
      'departure_airport_id',
      original.departureAirportId,
      edited.departureAirportId,
    );

    addIfChanged(
      'arrival_airport_id',
      original.arrivalAirportId,
      edited.arrivalAirportId,
    );

    // --------------------------------------------------------
    // Schedule
    // --------------------------------------------------------

    addIfChanged('departure_on', original.departureOn, edited.departureOn);

    addIfChanged('arrival_on', original.arrivalOn, edited.arrivalOn);

    addIfChanged(
      'departure_time',
      _normalizeTime(original.departureTime),
      _normalizeTime(edited.departureTime),
    );

    addIfChanged(
      'arrival_time',
      _normalizeTime(original.arrivalTime),
      _normalizeTime(edited.arrivalTime),
    );

    // --------------------------------------------------------
    // Status
    // --------------------------------------------------------

    addIfChanged('status', original.status.apiValue, edited.status.apiValue);

    // --------------------------------------------------------
    // Airline
    // --------------------------------------------------------

    final airlineChanged =
        original.airlineId != edited.airlineId ||
        _normalizeText(original.airlineName) !=
            _normalizeText(edited.airlineName);

    if (airlineChanged) {
      // The two airline fields form one logical selection.
      //
      // Always send both when the selection changes so that
      // switching between catalog/manual/none clears the
      // previous representation.
      changes['airline_id'] = edited.airlineId;
      changes['airline_name'] = _normalizeText(edited.airlineName);
    }

    addIfChanged(
      'flight_number',
      _normalizeUppercase(original.flightNumber),
      _normalizeUppercase(edited.flightNumber),
    );

    // --------------------------------------------------------
    // Aircraft and passenger information
    // --------------------------------------------------------

    addIfChanged(
      'aircraft_type',
      _normalizeText(original.aircraftType),
      _normalizeText(edited.aircraftType),
    );

    addIfChanged(
      'aircraft_registration',
      _normalizeUppercase(original.aircraftRegistration),
      _normalizeUppercase(edited.aircraftRegistration),
    );

    addIfChanged(
      'seat',
      _normalizeUppercase(original.seat),
      _normalizeUppercase(edited.seat),
    );

    addIfChanged(
      'cabin_class',
      original.cabinClass?.apiValue,
      edited.cabinClass?.apiValue,
    );

    addIfChanged(
      'notes',
      _normalizeText(original.notes),
      _normalizeText(edited.notes),
    );

    if (changes.isEmpty) {
      return null;
    }

    return FlightPatch(changes);
  }

  static String? _normalizeText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static String? _normalizeUppercase(String? value) {
    return _normalizeText(value)?.toUpperCase();
  }

  static String? _normalizeTime(String? value) {
    final normalized = _normalizeText(value);

    if (normalized == null) {
      return null;
    }

    // The form currently edits hours and minutes.
    //
    // Backend responses may include seconds:
    // 19:20:00 -> 19:20
    //
    // Preserve unchanged values instead of treating
    // serialization precision as a user edit.
    final components = normalized.split(':');

    if (components.length >= 2) {
      return '${components[0]}:${components[1]}';
    }

    return normalized;
  }
}
