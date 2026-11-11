import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_date_compatibility.dart';

PartialVisitDate day(int year, int month, int day) {
  return PartialVisitDate(
    date: DateTime(year, month, day),
    precision: VisitDatePrecision.day,
  );
}

PartialVisitDate month(int year, int month) {
  return PartialVisitDate(
    date: DateTime(year, month),
    precision: VisitDatePrecision.month,
  );
}

PartialVisitDate year(int year) {
  return PartialVisitDate(
    date: DateTime(year),
    precision: VisitDatePrecision.year,
  );
}

Trip testTrip({PartialVisitDate? start, PartialVisitDate? end}) {
  return Trip(
    id: 'trip-1',
    name: 'Japan 2027',
    description: null,
    startedOn: start,
    endedOn: end,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  group('Trip date compatibility', () {
    test('exact overlapping ranges are a match', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(result, TripDateCompatibility.match);
    });

    test('partially overlapping exact ranges are a match', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 20),
        visitStart: day(2027, 4, 18),
        visitEnd: day(2027, 4, 25),
      );

      expect(result, TripDateCompatibility.match);
    });

    test('ranges touching on the same day are a match', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 20),
        visitStart: day(2027, 4, 20),
        visitEnd: day(2027, 4, 25),
      );

      expect(result, TripDateCompatibility.match);
    });

    test('disjoint ranges return none', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: day(2027, 5, 1),
        visitEnd: day(2027, 5, 5),
      );

      expect(result, TripDateCompatibility.none);
    });

    test('same month with uncertain days is possible', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: month(2027, 4),
        visitEnd: month(2027, 4),
      );

      expect(result, TripDateCompatibility.possible);
    });

    test('entire month covered by Trip is a match', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 1),
        tripEnd: day(2027, 4, 30),
        visitStart: month(2027, 4),
        visitEnd: month(2027, 4),
      );

      expect(result, TripDateCompatibility.match);
    });

    test('year-only visit against exact Trip is possible', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: year(2027),
        visitEnd: year(2027),
      );

      expect(result, TripDateCompatibility.possible);
    });

    test('different years return none', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: year(2026),
        visitEnd: year(2026),
      );

      expect(result, TripDateCompatibility.none);
    });

    test('missing dates do not generate suggestions', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: null,
        visitEnd: null,
      );

      expect(result, TripDateCompatibility.none);
    });

    test('incomplete ranges do not generate suggestions', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        visitStart: day(2027, 4, 12),
        visitEnd: null,
      );

      expect(result, TripDateCompatibility.none);
    });

    test('impossible ranges return none', () {
      final result = evaluateTripDateCompatibility(
        tripStart: day(2027, 4, 25),
        tripEnd: day(2027, 4, 10),
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(result, TripDateCompatibility.none);
    });
  });

  group('Visit model integration', () {
    test('CountryVisit uses its declared precisions', () {
      final trip = testTrip(start: day(2027, 4, 10), end: day(2027, 4, 25));

      final visit = CountryVisit(
        id: 'country-visit-1',
        countryCode: 'JP',
        startedOn: DateTime(2027, 4),
        endedOn: DateTime(2027, 4),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
        createdAt: DateTime(2027),
        updatedAt: DateTime(2027),
      );

      expect(
        countryVisitTripCompatibility(trip: trip, visit: visit),
        TripDateCompatibility.possible,
      );
    });

    test('CityVisit uses its declared precisions', () {
      final trip = testTrip(start: day(2027, 4, 10), end: day(2027, 4, 25));

      final visit = CityVisit(
        id: 'city-visit-1',
        cityId: 123,
        cityName: 'Tokyo',
        countryCode: 'JP',
        countryName: 'Japan',
        startedOn: DateTime(2027, 4, 12),
        endedOn: DateTime(2027, 4, 16),
        startedOnPrecision: VisitDatePrecision.day,
        endedOnPrecision: VisitDatePrecision.day,
        createdAt: DateTime(2027),
        updatedAt: DateTime(2027),
      );

      expect(
        cityVisitTripCompatibility(trip: trip, visit: visit),
        TripDateCompatibility.match,
      );
    });
  });
}
