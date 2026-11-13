import '../../domain/flight_timing.dart';

/// Presentation formatting for backend-calculated flight timing.
abstract final class FlightTimingFormatter {
  /// Formats an elapsed duration.
  ///
  /// Examples:
  /// 115 -> 1h 55m
  /// 60  -> 1h
  /// 45  -> 45m
  /// 1500 -> 25h
  static String duration(int? minutes) {
    if (minutes == null || minutes < 0) {
      return '—';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  /// Formats a UTC offset in minutes.
  ///
  /// Examples:
  /// 0    -> UTC+0
  /// 60   -> UTC+1
  /// 120  -> UTC+2
  /// -300 -> UTC-5
  /// 330  -> UTC+5:30
  /// 345  -> UTC+5:45
  static String utcOffset(int? minutes) {
    if (minutes == null) {
      return '—';
    }

    final sign = minutes < 0 ? '-' : '+';
    final absoluteMinutes = minutes.abs();

    final hours = absoluteMinutes ~/ 60;
    final remainingMinutes = absoluteMinutes % 60;

    if (remainingMinutes == 0) {
      return 'UTC$sign$hours';
    }

    final minuteText = remainingMinutes.toString().padLeft(2, '0');

    return 'UTC$sign$hours:$minuteText';
  }

  /// Returns an offset label only when the backend has
  /// resolved the local time unambiguously.
  static String localTimeOffset(FlightLocalTime? localTime) {
    if (localTime == null || localTime.status != FlightLocalTimeStatus.valid) {
      return 'Local time';
    }

    final offset = localTime.utcOffsetMinutes;

    if (offset == null) {
      return 'Local time';
    }

    return utcOffset(offset);
  }

  /// Describes why a schedule cannot be interpreted.
  ///
  /// Useful for accessible labels or contextual information.
  static String? statusDescription(FlightLocalTime? localTime) {
    if (localTime == null) {
      return null;
    }

    return switch (localTime.status) {
      FlightLocalTimeStatus.valid => null,
      FlightLocalTimeStatus.ambiguous =>
        'This local time occurs twice due to a clock change.',
      FlightLocalTimeStatus.nonexistent =>
        'This local time does not exist due to a clock change.',
      FlightLocalTimeStatus.unavailable =>
        'Timezone information is unavailable.',
    };
  }
}
