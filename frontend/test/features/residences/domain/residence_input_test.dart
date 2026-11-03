import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResidenceInput', () {
    test('serializes a country residence with month precision', () {
      final input = ResidenceInput(
        countryCode: ' pt ',
        startedOn: DateTime(2020, 3, 15),
        startedOnPrecision: VisitDatePrecision.month,
        endedOn: DateTime(2023, 8, 20),
        endedOnPrecision: VisitDatePrecision.month,
        note: '  Studied here.  ',
      );

      expect(input.toJson(), {
        'country_code': 'PT',
        'city_id': null,
        'started_on': '2020-03-01',
        'started_on_precision': 'month',
        'ended_on': '2023-08-01',
        'ended_on_precision': 'month',
        'note': 'Studied here.',
      });
    });

    test('serializes a city residence with day precision', () {
      final input = ResidenceInput(
        countryCode: 'PT',
        cityId: 123,
        startedOn: DateTime(2020, 3, 15),
        startedOnPrecision: VisitDatePrecision.day,
        endedOn: DateTime(2023, 8, 20),
        endedOnPrecision: VisitDatePrecision.day,
      );

      expect(input.toJson()['city_id'], 123);
      expect(input.toJson()['started_on'], '2020-03-15');
      expect(input.toJson()['ended_on'], '2023-08-20');
    });

    test('rejects year precision', () {
      expect(
        () => ResidenceInput(
          countryCode: 'PT',
          startedOn: DateTime(2020),
          startedOnPrecision: VisitDatePrecision.year,
          endedOn: DateTime(2023),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid country codes', () {
      expect(
        () => ResidenceInput(
          countryCode: 'PORTUGAL',
          startedOn: DateTime(2020),
          startedOnPrecision: VisitDatePrecision.month,
          endedOn: DateTime(2023),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        throwsArgumentError,
      );
    });

    test('rejects notes longer than 1000 characters', () {
      expect(
        () => ResidenceInput(
          countryCode: 'PT',
          startedOn: DateTime(2020),
          startedOnPrecision: VisitDatePrecision.month,
          endedOn: DateTime(2023),
          endedOnPrecision: VisitDatePrecision.month,
          note: 'A' * 1001,
        ),
        throwsArgumentError,
      );
    });
  });
}
