import 'package:beenaround/features/flights/domain/flight_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightLocalTime.fromJson', () {
    test('parses a valid local time', () {
      final result = FlightLocalTime.fromJson({
        'status': 'valid',
        'utc_offset_minutes': 60,
      });

      expect(result.status, FlightLocalTimeStatus.valid);
      expect(result.utcOffsetMinutes, 60);
      expect(result.isValid, isTrue);
    });

    test('parses an ambiguous local time', () {
      final result = FlightLocalTime.fromJson({
        'status': 'ambiguous',
        'utc_offset_minutes': null,
      });

      expect(result.status, FlightLocalTimeStatus.ambiguous);
      expect(result.utcOffsetMinutes, isNull);
      expect(result.isValid, isFalse);
    });

    test('parses a nonexistent local time', () {
      final result = FlightLocalTime.fromJson({
        'status': 'nonexistent',
        'utc_offset_minutes': null,
      });

      expect(result.status, FlightLocalTimeStatus.nonexistent);
      expect(result.utcOffsetMinutes, isNull);
    });

    test('parses unavailable local time', () {
      final result = FlightLocalTime.fromJson({
        'status': 'unavailable',
        'utc_offset_minutes': null,
      });

      expect(result.status, FlightLocalTimeStatus.unavailable);
    });

    test('rejects an unknown status', () {
      expect(
        () => FlightLocalTime.fromJson({
          'status': 'unknown',
          'utc_offset_minutes': null,
        }),
        throwsFormatException,
      );
    });

    test('rejects valid time without an offset', () {
      expect(
        () => FlightLocalTime.fromJson({
          'status': 'valid',
          'utc_offset_minutes': null,
        }),
        throwsFormatException,
      );
    });

    test('rejects unresolved time with an offset', () {
      expect(
        () => FlightLocalTime.fromJson({
          'status': 'ambiguous',
          'utc_offset_minutes': 60,
        }),
        throwsFormatException,
      );
    });

    test('rejects non-integer offsets', () {
      expect(
        () => FlightLocalTime.fromJson({
          'status': 'valid',
          'utc_offset_minutes': 1.5,
        }),
        throwsFormatException,
      );
    });
  });

  group('FlightTiming.fromJson', () {
    test('parses a valid flight duration', () {
      final result = FlightTiming.fromJson({
        'departure': {'status': 'valid', 'utc_offset_minutes': 60},
        'arrival': {'status': 'valid', 'utc_offset_minutes': 120},
        'duration_minutes': 115,
      });

      expect(result.departure.utcOffsetMinutes, 60);
      expect(result.arrival.utcOffsetMinutes, 120);
      expect(result.durationMinutes, 115);
    });

    test('allows unavailable duration', () {
      final result = FlightTiming.fromJson({
        'departure': {'status': 'valid', 'utc_offset_minutes': 60},
        'arrival': {'status': 'unavailable', 'utc_offset_minutes': null},
        'duration_minutes': null,
      });

      expect(result.durationMinutes, isNull);
    });

    test('rejects negative durations', () {
      expect(
        () => FlightTiming.fromJson({
          'departure': {'status': 'valid', 'utc_offset_minutes': 60},
          'arrival': {'status': 'valid', 'utc_offset_minutes': 120},
          'duration_minutes': -10,
        }),
        throwsFormatException,
      );
    });

    test('rejects duration with unresolved times', () {
      expect(
        () => FlightTiming.fromJson({
          'departure': {'status': 'ambiguous', 'utc_offset_minutes': null},
          'arrival': {'status': 'valid', 'utc_offset_minutes': 120},
          'duration_minutes': 115,
        }),
        throwsFormatException,
      );
    });

    test('rejects missing arrival data', () {
      expect(
        () => FlightTiming.fromJson({
          'departure': {'status': 'valid', 'utc_offset_minutes': 60},
          'duration_minutes': 115,
        }),
        throwsFormatException,
      );
    });
  });
}
