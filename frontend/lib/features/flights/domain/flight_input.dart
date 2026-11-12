import 'flight.dart';

/// Input for creating one personal flight.
///
/// The authenticated user is resolved by the backend.
/// Trip associations are managed separately.
class FlightCreateInput {
  const FlightCreateInput({
    required this.departureAirportId,
    required this.arrivalAirportId,
    required this.departureOn,
    required this.status,
    this.airlineId,
    this.airlineName,
    this.flightNumber,
    this.departureTime,
    this.arrivalOn,
    this.arrivalTime,
    this.aircraftType,
    this.aircraftRegistration,
    this.seat,
    this.cabinClass,
    this.notes,
  });

  final int departureAirportId;
  final int arrivalAirportId;
  final String departureOn;
  final FlightStatus status;

  final int? airlineId;
  final String? airlineName;
  final String? flightNumber;

  final String? departureTime;
  final String? arrivalOn;
  final String? arrivalTime;

  final String? aircraftType;
  final String? aircraftRegistration;
  final String? seat;
  final FlightCabinClass? cabinClass;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'departure_airport_id': departureAirportId,
      'arrival_airport_id': arrivalAirportId,
      'departure_on': departureOn,
      'status': status.apiValue,
      if (airlineId != null) 'airline_id': airlineId,
      if (airlineName != null) 'airline_name': airlineName,
      if (flightNumber != null) 'flight_number': flightNumber,
      if (departureTime != null) 'departure_time': departureTime,
      if (arrivalOn != null) 'arrival_on': arrivalOn,
      if (arrivalTime != null) 'arrival_time': arrivalTime,
      if (aircraftType != null) 'aircraft_type': aircraftType,
      if (aircraftRegistration != null)
        'aircraft_registration': aircraftRegistration,
      if (seat != null) 'seat': seat,
      if (cabinClass != null) 'cabin_class': cabinClass!.apiValue,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Explicit partial update.
///
/// A missing key means "leave unchanged".
/// A key with a null value means "clear this optional field".
///
/// Only the allowlisted API fields can be changed.
class FlightPatch {
  FlightPatch(Map<String, dynamic> changes)
    : changes = Map.unmodifiable(_validateChanges(changes));

  static const Set<String> _allowedFields = {
    'departure_airport_id',
    'arrival_airport_id',
    'departure_on',
    'status',
    'airline_id',
    'airline_name',
    'flight_number',
    'departure_time',
    'arrival_on',
    'arrival_time',
    'aircraft_type',
    'aircraft_registration',
    'seat',
    'cabin_class',
    'notes',
  };

  static const Set<String> _requiredFields = {
    'departure_airport_id',
    'arrival_airport_id',
    'departure_on',
    'status',
  };

  final Map<String, dynamic> changes;

  bool get isEmpty => changes.isEmpty;

  Map<String, dynamic> toJson() => Map.of(changes);

  static Map<String, dynamic> _validateChanges(Map<String, dynamic> changes) {
    if (changes.isEmpty) {
      throw ArgumentError('Flight patch cannot be empty.');
    }

    for (final entry in changes.entries) {
      if (!_allowedFields.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'field',
          'Field cannot be updated.',
        );
      }

      if (_requiredFields.contains(entry.key) && entry.value == null) {
        throw ArgumentError.value(
          entry.key,
          'field',
          'Required flight field cannot be null.',
        );
      }
    }

    return changes;
  }
}
