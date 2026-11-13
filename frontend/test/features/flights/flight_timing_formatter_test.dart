import 'package:beenaround/features/flights/domain/flight_timing.dart';
import 'package:beenaround/features/flights/presentation/formatters/flight_timing_formatter.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightTimingFormatter.duration', () {
    test('formats hours and minutes', () {
      expect(FlightTimingFormatter.duration(115), '1h 55m');
      expect(FlightTimingFormatter.duration(150), '2h 30m');
    });

    test('formats complete hours', () {
      expect(FlightTimingFormatter.duration(60), '1h');
      expect(FlightTimingFormatter.duration(120), '2h');
    });

    test('formats durations under one hour', () {
      expect(FlightTimingFormatter.duration(45), '45m');
      expect(FlightTimingFormatter.duration(0), '0m');
    });

    test('supports long flights', () {
      expect(FlightTimingFormatter.duration(1500), '25h');
    });

    test('handles unavailable or invalid duration', () {
      expect(FlightTimingFormatter.duration(null), '—');
      expect(FlightTimingFormatter.duration(-1), '—');
    });
  });

  group('FlightTimingFormatter.utcOffset', () {
    test('formats positive UTC offsets', () {
      expect(FlightTimingFormatter.utcOffset(0), 'UTC+0');
      expect(FlightTimingFormatter.utcOffset(60), 'UTC+1');
      expect(FlightTimingFormatter.utcOffset(120), 'UTC+2');
    });

    test('formats negative UTC offsets', () {
      expect(FlightTimingFormatter.utcOffset(-60), 'UTC-1');
      expect(FlightTimingFormatter.utcOffset(-300), 'UTC-5');
    });

    test('supports offsets with additional minutes', () {
      expect(FlightTimingFormatter.utcOffset(330), 'UTC+5:30');
      expect(FlightTimingFormatter.utcOffset(345), 'UTC+5:45');
      expect(FlightTimingFormatter.utcOffset(-210), 'UTC-3:30');
    });

    test('handles unavailable offsets', () {
      expect(FlightTimingFormatter.utcOffset(null), '—');
    });
  });

  group('FlightTimingFormatter.localTimeOffset', () {
    test('shows offset for a valid local time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.valid,
        utcOffsetMinutes: 60,
      );

      expect(FlightTimingFormatter.localTimeOffset(localTime), 'UTC+1');
    });

    test('does not invent an offset for ambiguous time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.ambiguous,
        utcOffsetMinutes: null,
      );

      expect(FlightTimingFormatter.localTimeOffset(localTime), 'Local time');
    });

    test('does not invent an offset for nonexistent time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.nonexistent,
        utcOffsetMinutes: null,
      );

      expect(FlightTimingFormatter.localTimeOffset(localTime), 'Local time');
    });

    test('handles missing timing information', () {
      expect(FlightTimingFormatter.localTimeOffset(null), 'Local time');
    });
  });

  group('FlightTimingFormatter.statusDescription', () {
    test('describes ambiguous local time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.ambiguous,
        utcOffsetMinutes: null,
      );

      expect(
        FlightTimingFormatter.statusDescription(localTime),
        contains('occurs twice'),
      );
    });

    test('describes nonexistent local time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.nonexistent,
        utcOffsetMinutes: null,
      );

      expect(
        FlightTimingFormatter.statusDescription(localTime),
        contains('does not exist'),
      );
    });

    test('returns no warning for valid local time', () {
      const localTime = FlightLocalTime(
        status: FlightLocalTimeStatus.valid,
        utcOffsetMinutes: 60,
      );

      expect(FlightTimingFormatter.statusDescription(localTime), isNull);
    });
  });

  group('FlightLocalTimeStatus', () {
    test('parses known API values', () {
      expect(
        FlightLocalTimeStatus.fromValue('valid'),
        FlightLocalTimeStatus.valid,
      );

      expect(
        FlightLocalTimeStatus.fromValue('ambiguous'),
        FlightLocalTimeStatus.ambiguous,
      );

      expect(
        FlightLocalTimeStatus.fromValue('nonexistent'),
        FlightLocalTimeStatus.nonexistent,
      );

      expect(
        FlightLocalTimeStatus.fromValue('unavailable'),
        FlightLocalTimeStatus.unavailable,
      );
    });

    test('rejects unknown API values', () {
      expect(
        () => FlightLocalTimeStatus.fromValue('invalid'),
        throwsFormatException,
      );
    });
  });
}
