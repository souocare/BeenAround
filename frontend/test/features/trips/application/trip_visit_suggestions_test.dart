import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/trips/application/trip_visit_suggestions.dart';
import 'package:beenaround/features/trips/domain/trip_date_compatibility.dart';

import 'package:flutter_test/flutter_test.dart';

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

CountryVisit countryVisit(
  String id, {
  required DateTime start,
  required DateTime end,
  VisitDatePrecision precision = VisitDatePrecision.day,
}) {
  return CountryVisit(
    id: id,
    countryCode: 'JP',
    startedOn: start,
    endedOn: end,
    startedOnPrecision: precision,
    endedOnPrecision: precision,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit cityVisit(
  String id, {
  required DateTime start,
  required DateTime end,
}) {
  return CityVisit(
    id: id,
    cityId: 1,
    cityName: 'Tokyo',
    countryCode: 'JP',
    countryName: 'Japan',
    startedOn: start,
    endedOn: end,
    startedOnPrecision: VisitDatePrecision.day,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  group('Country visit suggestions', () {
    test('suggests visits with overlapping dates', () {
      final result = findCompatibleCountryVisits(
        visits: [
          countryVisit(
            'japan',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
          countryVisit(
            'other',
            start: DateTime(2027, 6, 1),
            end: DateTime(2027, 6, 5),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
      );

      expect(result.length, 1);
      expect(result.single.visit.id, 'japan');

      expect(result.single.compatibility, TripDateCompatibility.match);
    });

    test('distinguishes possible matches from confirmed matches', () {
      final result = findCompatibleCountryVisits(
        visits: [
          countryVisit(
            'possible',
            start: DateTime(2027, 4),
            end: DateTime(2027, 4),
            precision: VisitDatePrecision.month,
          ),
          countryVisit(
            'confirmed',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
      );

      expect(result.map((item) => item.visit.id).toList(), [
        'confirmed',
        'possible',
      ]);

      expect(result.last.compatibility, TripDateCompatibility.possible);
    });

    test('does not suggest already selected visits', () {
      final result = findCompatibleCountryVisits(
        visits: [
          countryVisit(
            'selected',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        excludedVisitIds: {'selected'},
      );

      expect(result, isEmpty);
    });

    test('does not suggest visits when Trip dates are incomplete', () {
      final result = findCompatibleCountryVisits(
        visits: [
          countryVisit(
            'japan',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: null,
      );

      expect(result, isEmpty);
    });

    test('does not suggest visits outside the Trip dates', () {
      final result = findCompatibleCountryVisits(
        visits: [
          countryVisit(
            'japan',
            start: DateTime(2027, 6, 1),
            end: DateTime(2027, 6, 5),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
      );

      expect(result, isEmpty);
    });
  });

  group('City visit suggestions', () {
    test('suggests existing compatible city visits', () {
      final result = findCompatibleCityVisits(
        visits: [
          cityVisit(
            'tokyo',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
      );

      expect(result.length, 1);
      expect(result.single.visit.id, 'tokyo');
    });

    test('excludes already selected city visits', () {
      final result = findCompatibleCityVisits(
        visits: [
          cityVisit(
            'tokyo',
            start: DateTime(2027, 4, 12),
            end: DateTime(2027, 4, 16),
          ),
        ],
        tripStart: day(2027, 4, 10),
        tripEnd: day(2027, 4, 25),
        excludedVisitIds: {'tokyo'},
      );

      expect(result, isEmpty);
    });
  });
}
