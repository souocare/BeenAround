/// Resolution status of an airport-local flight time.
///
/// The backend is responsible for applying IANA timezone
/// rules, including daylight-saving transitions.
enum FlightLocalTimeStatus {
  valid('valid'),
  ambiguous('ambiguous'),
  nonexistent('nonexistent'),
  unavailable('unavailable');

  const FlightLocalTimeStatus(this.value);

  final String value;

  static FlightLocalTimeStatus fromValue(String value) {
    for (final status in FlightLocalTimeStatus.values) {
      if (status.value == value) {
        return status;
      }
    }

    throw FormatException('Unknown flight local time status: $value');
  }
}

/// Interpretation of one airport-local schedule.
class FlightLocalTime {
  const FlightLocalTime({required this.status, required this.utcOffsetMinutes});

  final FlightLocalTimeStatus status;

  /// UTC offset at the flight's local date and time.
  ///
  /// This is not the airport's permanent UTC offset.
  final int? utcOffsetMinutes;

  bool get isValid => status == FlightLocalTimeStatus.valid;

  factory FlightLocalTime.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];

    if (rawStatus is! String) {
      throw const FormatException('Missing flight local time status.');
    }

    final status = FlightLocalTimeStatus.fromValue(rawStatus);

    final rawOffset = json['utc_offset_minutes'];

    if (rawOffset != null && rawOffset is! int) {
      throw const FormatException('Invalid UTC offset.');
    }

    if (status == FlightLocalTimeStatus.valid && rawOffset == null) {
      throw const FormatException('Valid local time requires a UTC offset.');
    }

    if (status != FlightLocalTimeStatus.valid && rawOffset != null) {
      throw const FormatException(
        'Unresolved local time cannot have a UTC offset.',
      );
    }

    return FlightLocalTime(status: status, utcOffsetMinutes: rawOffset as int?);
  }
}

/// Calculated timing for one flight segment.
///
/// Values originate from the backend's timezone-aware
/// calculation service.
class FlightTiming {
  const FlightTiming({
    required this.departure,
    required this.arrival,
    required this.durationMinutes,
  });

  final FlightLocalTime departure;
  final FlightLocalTime arrival;

  /// Actual elapsed duration, not a subtraction of local times.
  ///
  /// Null when the calculation cannot be made reliably.
  final int? durationMinutes;

  factory FlightTiming.fromJson(Map<String, dynamic> json) {
    final departureJson = json['departure'];
    final arrivalJson = json['arrival'];
    final rawDuration = json['duration_minutes'];

    if (departureJson is! Map<String, dynamic> ||
        arrivalJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid flight timing response.');
    }

    if (rawDuration != null && (rawDuration is! int || rawDuration < 0)) {
      throw const FormatException('Invalid flight duration.');
    }

    final departure = FlightLocalTime.fromJson(departureJson);
    final arrival = FlightLocalTime.fromJson(arrivalJson);

    if (rawDuration != null && (!departure.isValid || !arrival.isValid)) {
      throw const FormatException(
        'Flight duration requires valid local times.',
      );
    }

    return FlightTiming(
      departure: departure,
      arrival: arrival,
      durationMinutes: rawDuration as int?,
    );
  }
}
