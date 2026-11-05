import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/trips/domain/trip.dart';

void main() {
  Map<String, dynamic> validJson() {
    return {
      'id': 'trip-1',
      'name': 'Japan 2027',
      'description': 'Spring holiday',
      'started_on': '2027-04-01',
      'started_on_precision': 'month',
      'ended_on': '2027-05-01',
      'ended_on_precision': 'month',
      'created_at': '2026-11-05T10:00:00Z',
      'updated_at': '2026-11-05T10:00:00Z',
    };
  }

  test('parses a valid Trip', () {
    final trip = Trip.fromJson(validJson());

    expect(trip.id, 'trip-1');
    expect(trip.name, 'Japan 2027');
    expect(trip.description, 'Spring holiday');

    expect(trip.startedOn?.date.year, 2027);
    expect(trip.startedOn?.date.month, 4);
    expect(trip.startedOn?.precision, VisitDatePrecision.month);

    expect(trip.endedOn?.date.month, 5);
    expect(trip.endedOn?.precision, VisitDatePrecision.month);

    expect(trip.hasDates, isTrue);
    expect(trip.hasCompleteDateRange, isTrue);
  });

  test('accepts a Trip without dates', () {
    final json = validJson()
      ..['started_on'] = null
      ..['started_on_precision'] = null
      ..['ended_on'] = null
      ..['ended_on_precision'] = null;

    final trip = Trip.fromJson(json);

    expect(trip.startedOn, isNull);
    expect(trip.endedOn, isNull);
    expect(trip.hasDates, isFalse);
    expect(trip.hasCompleteDateRange, isFalse);
  });

  test('accepts only a start date', () {
    final json = validJson()
      ..['ended_on'] = null
      ..['ended_on_precision'] = null;

    final trip = Trip.fromJson(json);

    expect(trip.startedOn, isNotNull);
    expect(trip.endedOn, isNull);
    expect(trip.hasCompleteDateRange, isFalse);
  });

  test('rejects a date without precision', () {
    final json = validJson()..['started_on_precision'] = null;

    expect(() => Trip.fromJson(json), throwsFormatException);
  });

  test('rejects precision without date', () {
    final json = validJson()..['started_on'] = null;

    expect(() => Trip.fromJson(json), throwsFormatException);
  });

  test('rejects non-canonical month dates', () {
    final json = validJson()..['started_on'] = '2027-04-15';

    expect(() => Trip.fromJson(json), throwsFormatException);
  });

  test('rejects non-canonical year dates', () {
    final json = validJson()..['started_on_precision'] = 'year';

    expect(() => Trip.fromJson(json), throwsFormatException);
  });

  test('rejects unknown precision', () {
    final json = validJson()..['started_on_precision'] = 'week';

    expect(() => Trip.fromJson(json), throwsFormatException);
  });

  test('rejects invalid date values', () {
    final json = validJson()..['started_on'] = 'invalid-date';

    expect(() => Trip.fromJson(json), throwsFormatException);
  });
}
