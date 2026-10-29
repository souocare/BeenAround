import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/domain/country_visit_date_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryVisitDateValidator', () {
    test('rejects visits without dates', () {
      expect(
        CountryVisitDateValidator.validate(),
        'Start and end dates are required.',
      );
    });

    test('rejects a start date without an end date', () {
      expect(
        CountryVisitDateValidator.validate(startedOn: DateTime(2026, 10, 10)),
        'Start and end dates are required.',
      );
    });

    test('rejects an end date without a start date', () {
      expect(
        CountryVisitDateValidator.validate(endedOn: DateTime(2026, 10, 15)),
        'Start and end dates are required.',
      );
    });

    test('accepts valid date ranges', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
        isNull,
      );
    });

    test('accepts the same start and end date', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 10),
        ),
        isNull,
      );
    });

    test('rejects an end date earlier than the start date', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2026, 10, 15),
          endedOn: DateTime(2026, 10, 10),
        ),
        'End date cannot be earlier than start date.',
      );
    });

    test('compares calendar dates rather than times', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2026, 10, 10, 23, 30),
          endedOn: DateTime(2026, 10, 10, 8, 15),
        ),
        isNull,
      );
    });

    test('accepts overlapping month precision ranges', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 1, 1),
          startedOnPrecision: VisitDatePrecision.month,
          endedOn: DateTime(2024, 1, 1),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        isNull,
      );
    });

    test('accepts a year precision range', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 1, 1),
          startedOnPrecision: VisitDatePrecision.year,
          endedOn: DateTime(2024, 1, 1),
          endedOnPrecision: VisitDatePrecision.year,
        ),
        isNull,
      );
    });

    test('accepts an exact date within a partial year', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 1, 1),
          startedOnPrecision: VisitDatePrecision.year,
          endedOn: DateTime(2024, 6, 15),
          endedOnPrecision: VisitDatePrecision.day,
        ),
        isNull,
      );
    });

    test('accepts an exact start date within a partial end month', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 6, 15),
          startedOnPrecision: VisitDatePrecision.day,
          endedOn: DateTime(2024, 6, 1),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        isNull,
      );
    });

    test('rejects a month range ending before the start month', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 12, 1),
          startedOnPrecision: VisitDatePrecision.month,
          endedOn: DateTime(2024, 1, 1),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        'End date cannot be earlier than start date.',
      );
    });

    test('rejects a year range ending before the start year', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2025, 1, 1),
          startedOnPrecision: VisitDatePrecision.year,
          endedOn: DateTime(2024, 1, 1),
          endedOnPrecision: VisitDatePrecision.year,
        ),
        'End date cannot be earlier than start date.',
      );
    });

    test('rejects precision without a start date', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOnPrecision: VisitDatePrecision.month,
        ),
        'A start date precision requires a start date.',
      );
    });

    test('rejects precision without an end date', () {
      expect(
        CountryVisitDateValidator.validate(
          endedOnPrecision: VisitDatePrecision.year,
        ),
        'An end date precision requires an end date.',
      );
    });

    test('accepts legacy dates without explicit precision', () {
      expect(
        CountryVisitDateValidator.validate(
          startedOn: DateTime(2024, 6, 10),
          endedOn: DateTime(2024, 6, 15),
        ),
        isNull,
      );
    });
  });
}
