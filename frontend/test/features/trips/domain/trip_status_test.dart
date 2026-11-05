import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_status.dart';

void main() {
  Trip trip({PartialVisitDate? start, PartialVisitDate? end}) {
    return Trip(
      id: 'trip-1',
      name: 'Test Trip',
      description: null,
      startedOn: start,
      endedOn: end,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  PartialVisitDate partial(
    int year,
    int month,
    int day,
    VisitDatePrecision precision,
  ) {
    return PartialVisitDate(
      date: DateTime(year, month, day),
      precision: precision,
    );
  }

  final today = DateTime(2027, 4, 15);

  test('no dates means undated', () {
    expect(resolveTripStatus(trip(), now: today), TripStatus.undated);
  });

  test('future exact dates mean upcoming', () {
    final value = trip(
      start: partial(2027, 4, 20, VisitDatePrecision.day),
      end: partial(2027, 4, 25, VisitDatePrecision.day),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.upcoming);
  });

  test('past exact dates mean completed', () {
    final value = trip(
      start: partial(2027, 4, 1, VisitDatePrecision.day),
      end: partial(2027, 4, 10, VisitDatePrecision.day),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.completed);
  });

  test('exact dates covering today mean ongoing', () {
    final value = trip(
      start: partial(2027, 4, 10, VisitDatePrecision.day),
      end: partial(2027, 4, 20, VisitDatePrecision.day),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.ongoing);
  });

  test('start date is inclusive', () {
    final value = trip(
      start: partial(2027, 4, 15, VisitDatePrecision.day),
      end: partial(2027, 4, 20, VisitDatePrecision.day),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.ongoing);
  });

  test('end date is inclusive', () {
    final value = trip(
      start: partial(2027, 4, 10, VisitDatePrecision.day),
      end: partial(2027, 4, 15, VisitDatePrecision.day),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.ongoing);
  });

  test('future year means upcoming', () {
    final value = trip(start: partial(2028, 1, 1, VisitDatePrecision.year));

    expect(resolveTripStatus(value, now: today), TripStatus.upcoming);
  });

  test('past end year means completed', () {
    final value = trip(end: partial(2026, 1, 1, VisitDatePrecision.year));

    expect(resolveTripStatus(value, now: today), TripStatus.completed);
  });

  test('current month without exact dates is uncertain', () {
    final value = trip(
      start: partial(2027, 4, 1, VisitDatePrecision.month),
      end: partial(2027, 4, 1, VisitDatePrecision.month),
    );

    expect(resolveTripStatus(value, now: today), TripStatus.undated);
  });

  test('unknown end date does not imply ongoing', () {
    final value = trip(start: partial(2027, 4, 10, VisitDatePrecision.day));

    expect(resolveTripStatus(value, now: today), TripStatus.undated);
  });

  test('unknown start date does not imply ongoing', () {
    final value = trip(end: partial(2027, 4, 20, VisitDatePrecision.day));

    expect(resolveTripStatus(value, now: today), TripStatus.undated);
  });
}
