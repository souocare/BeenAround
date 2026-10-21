import 'package:beenaround/features/explore/domain/country_visit_date_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryVisitDateValidator', () {
    test('accepts visits without dates', () {
      expect(CountryVisitDateValidator.validate(), isNull);
    });

    test('accepts a start date without an end date', () {
      expect(
        CountryVisitDateValidator.validate(startedOn: DateTime(2026, 10, 10)),
        isNull,
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

    test('rejects an end date without a start date', () {
      expect(
        CountryVisitDateValidator.validate(endedOn: DateTime(2026, 10, 15)),
        'An end date requires a start date.',
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
  });
}
