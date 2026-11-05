import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('TripInput', () {
    test('serializes a Trip without dates', () {
      const input = TripInput(name: 'Japan 2027');

      expect(input.toJson(), {
        'name': 'Japan 2027',
        'description': null,
        'started_on': null,
        'started_on_precision': null,
        'ended_on': null,
        'ended_on_precision': null,
      });
    });

    test('normalizes name and description', () {
      const input = TripInput(
        name: '  Japan 2027  ',
        description: '  Spring holiday  ',
      );

      final payload = input.toJson();

      expect(payload['name'], 'Japan 2027');
      expect(payload['description'], 'Spring holiday');
    });

    test('normalizes an empty description to null', () {
      const input = TripInput(name: 'Japan', description: '   ');

      expect(input.toJson()['description'], isNull);
    });

    test('serializes exact dates', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 4, 10, VisitDatePrecision.day),
        endedOn: partial(2027, 4, 25, VisitDatePrecision.day),
      );

      final payload = input.toJson();

      expect(payload['started_on'], '2027-04-10');
      expect(payload['started_on_precision'], 'day');
      expect(payload['ended_on'], '2027-04-25');
      expect(payload['ended_on_precision'], 'day');
    });

    test('normalizes month precision', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 4, 15, VisitDatePrecision.month),
      );

      final payload = input.toJson();

      expect(payload['started_on'], '2027-04-01');
      expect(payload['started_on_precision'], 'month');
    });

    test('normalizes year precision', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 8, 20, VisitDatePrecision.year),
      );

      final payload = input.toJson();

      expect(payload['started_on'], '2027-01-01');
      expect(payload['started_on_precision'], 'year');
    });

    test('supports only a start date', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 4, 10, VisitDatePrecision.day),
      );

      final payload = input.toJson();

      expect(payload['started_on'], '2027-04-10');
      expect(payload['ended_on'], isNull);
    });

    test('supports only an end date', () {
      final input = TripInput(
        name: 'Japan',
        endedOn: partial(2027, 4, 25, VisitDatePrecision.day),
      );

      final payload = input.toJson();

      expect(payload['started_on'], isNull);
      expect(payload['ended_on'], '2027-04-25');
    });

    test('supports overlapping partial dates', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 4, 20, VisitDatePrecision.day),
        endedOn: partial(2027, 4, 15, VisitDatePrecision.month),
      );

      final payload = input.toJson();

      expect(payload['started_on'], '2027-04-20');
      expect(payload['ended_on'], '2027-04-01');
      expect(payload['ended_on_precision'], 'month');
    });

    test('rejects an invalid date interval', () {
      final input = TripInput(
        name: 'Japan',
        startedOn: partial(2027, 5, 10, VisitDatePrecision.day),
        endedOn: partial(2027, 4, 10, VisitDatePrecision.day),
      );

      expect(() => input.toJson(), throwsArgumentError);
    });

    test('rejects a blank name', () {
      const input = TripInput(name: '   ');

      expect(() => input.toJson(), throwsArgumentError);
    });

    test('rejects a name longer than 160 characters', () {
      final input = TripInput(name: 'A' * 161);

      expect(() => input.toJson(), throwsArgumentError);
    });

    test('accepts a name with exactly 160 characters', () {
      final input = TripInput(name: 'A' * 160);

      expect(input.toJson()['name'], 'A' * 160);
    });

    test('rejects a description longer than 5000 characters', () {
      final input = TripInput(name: 'Japan', description: 'A' * 5001);

      expect(() => input.toJson(), throwsArgumentError);
    });

    test('clears both date fields when absent', () {
      const input = TripInput(name: 'Updated Japan', description: null);

      final payload = input.toJson();

      expect(payload.containsKey('started_on'), isTrue);
      expect(payload.containsKey('started_on_precision'), isTrue);
      expect(payload.containsKey('ended_on'), isTrue);
      expect(payload.containsKey('ended_on_precision'), isTrue);

      expect(payload['started_on'], isNull);
      expect(payload['started_on_precision'], isNull);
      expect(payload['ended_on'], isNull);
      expect(payload['ended_on_precision'], isNull);
    });
  });
}
