import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/trips/application/trip_suggestions.dart';
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

Trip trip(
  String id,
  String name, {
  PartialVisitDate? start,
  PartialVisitDate? end,
}) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: start,
    endedOn: end,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  group('findCompatibleTrips', () {
    test('returns only compatible Trips', () {
      final result = findCompatibleTrips(
        trips: [
          trip(
            'japan',
            'Japan',
            start: day(2027, 4, 10),
            end: day(2027, 4, 25),
          ),
          trip(
            'portugal',
            'Portugal',
            start: day(2027, 6, 1),
            end: day(2027, 6, 10),
          ),
        ],
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(result.length, 1);
      expect(result.single.trip.id, 'japan');
      expect(result.single.compatibility, TripDateCompatibility.match);
    });

    test('orders confirmed matches before possible matches', () {
      final result = findCompatibleTrips(
        trips: [
          trip('possible', 'Asia', start: month(2027, 4), end: month(2027, 4)),
          trip(
            'confirmed',
            'Japan',
            start: day(2027, 4, 10),
            end: day(2027, 4, 25),
          ),
        ],
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(result.map((suggestion) => suggestion.trip.id).toList(), [
        'confirmed',
        'possible',
      ]);
    });

    test('excludes Trips that are already associated', () {
      final result = findCompatibleTrips(
        trips: [
          trip(
            'japan',
            'Japan',
            start: day(2027, 4, 10),
            end: day(2027, 4, 25),
          ),
          trip('asia', 'Asia', start: day(2027, 4, 1), end: day(2027, 4, 30)),
        ],
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
        excludedTripIds: {'japan'},
      );

      expect(result.length, 1);
      expect(result.single.trip.id, 'asia');
    });

    test('returns no suggestions when visit dates are incomplete', () {
      final result = findCompatibleTrips(
        trips: [
          trip(
            'japan',
            'Japan',
            start: day(2027, 4, 10),
            end: day(2027, 4, 25),
          ),
        ],
        visitStart: day(2027, 4, 12),
        visitEnd: null,
      );

      expect(result, isEmpty);
    });

    test('orders equal matches by name and then ID', () {
      final result = findCompatibleTrips(
        trips: [
          trip('z', 'Japan', start: day(2027, 4, 1), end: day(2027, 4, 30)),
          trip('b', 'Asia', start: day(2027, 4, 1), end: day(2027, 4, 30)),
          trip('a', 'Asia', start: day(2027, 4, 1), end: day(2027, 4, 30)),
        ],
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(result.map((suggestion) => suggestion.trip.id).toList(), [
        'a',
        'b',
        'z',
      ]);
    });
    test('recalculates compatible Trips when visit dates change', () {
      final trips = [
        trip(
          'japan',
          'Japan 2027',
          start: day(2027, 4, 10),
          end: day(2027, 4, 25),
        ),
        trip(
          'portugal',
          'Portugal 2027',
          start: day(2027, 6, 1),
          end: day(2027, 6, 15),
        ),
      ];

      final aprilSuggestions = findCompatibleTrips(
        trips: trips,
        visitStart: day(2027, 4, 12),
        visitEnd: day(2027, 4, 16),
      );

      expect(aprilSuggestions.map((suggestion) => suggestion.trip.id), [
        'japan',
      ]);

      final juneSuggestions = findCompatibleTrips(
        trips: trips,
        visitStart: day(2027, 6, 5),
        visitEnd: day(2027, 6, 10),
      );

      expect(juneSuggestions.map((suggestion) => suggestion.trip.id), [
        'portugal',
      ]);
    });
  });
}
