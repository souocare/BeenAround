import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/models/visit_date_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisitDateSerializer.formatDate', () {
    test('formats an exact date as YYYY-MM-DD', () {
      expect(
        VisitDateSerializer.formatDate(DateTime(2024, 6, 15)),
        '2024-06-15',
      );
    });

    test('pads single-digit months and days', () {
      expect(
        VisitDateSerializer.formatDate(DateTime(2024, 1, 5)),
        '2024-01-05',
      );
    });

    test('returns null for a missing date', () {
      expect(VisitDateSerializer.formatDate(null), isNull);
    });

    test('ignores time of day', () {
      expect(
        VisitDateSerializer.formatDate(DateTime(2024, 6, 15, 23, 45)),
        '2024-06-15',
      );
    });
  });

  group('VisitDateSerializer.createFields', () {
    test('serializes exact dates with day precision by default', () {
      final fields = VisitDateSerializer.createFields(
        startedOn: DateTime(2024, 6, 15),
        endedOn: DateTime(2024, 6, 20),
      );

      expect(fields, {
        'started_on': '2024-06-15',
        'started_on_precision': 'day',
        'ended_on': '2024-06-20',
        'ended_on_precision': 'day',
      });
    });

    test('serializes year precision', () {
      final fields = VisitDateSerializer.createFields(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2025, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.year,
      );

      expect(fields, {
        'started_on': '2024-01-01',
        'ended_on': '2025-01-01',
        'started_on_precision': 'year',
        'ended_on_precision': 'year',
      });
    });

    test('supports mixed date precisions', () {
      final fields = VisitDateSerializer.createFields(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 6, 15),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.day,
      );

      expect(fields, {
        'started_on': '2024-01-01',
        'ended_on': '2024-06-15',
        'started_on_precision': 'year',
        'ended_on_precision': 'day',
      });
    });
  });

  group('VisitDateSerializer.updateFields', () {
    test('preserves an empty PATCH', () {
      final fields = VisitDateSerializer.updateFields({});

      expect(fields, isEmpty);
    });

    test('serializes only the modified start date', () {
      final fields = VisitDateSerializer.updateFields({
        'started_on': DateTime(2024, 6, 15),
      });

      expect(fields, {'started_on': '2024-06-15'});

      expect(fields.containsKey('ended_on'), isFalse);
    });

    test('serializes only the modified end date', () {
      final fields = VisitDateSerializer.updateFields({
        'ended_on': DateTime(2024, 12, 1),
        'ended_on_precision': VisitDatePrecision.month,
      });

      expect(fields, {'ended_on': '2024-12-01', 'ended_on_precision': 'month'});

      expect(fields.containsKey('started_on'), isFalse);
      expect(fields.containsKey('started_on_precision'), isFalse);
    });

    test('serializes precision changes', () {
      final fields = VisitDateSerializer.updateFields({
        'started_on_precision': VisitDatePrecision.year,
      });

      expect(fields, {'started_on_precision': 'year'});
    });

    test('rejects null when clearing a date', () {
      expect(
        () => VisitDateSerializer.updateFields({'started_on': null}),
        throwsArgumentError,
      );
    });

    test('rejects null when clearing a precision', () {
      expect(
        () => VisitDateSerializer.updateFields({'ended_on_precision': null}),
        throwsArgumentError,
      );
    });

    test('preserves independent end-only updates', () {
      final fields = VisitDateSerializer.updateFields({
        'ended_on': DateTime(2024, 6, 15),
        'ended_on_precision': VisitDatePrecision.day,
      });

      expect(fields, {'ended_on': '2024-06-15', 'ended_on_precision': 'day'});

      expect(fields.containsKey('started_on'), isFalse);
    });

    test('rejects unsupported PATCH fields', () {
      expect(
        () => VisitDateSerializer.updateFields({'country_code': 'PT'}),
        throwsArgumentError,
      );
    });

    test('rejects invalid date types', () {
      expect(
        () => VisitDateSerializer.updateFields({'started_on': '2024-06-15'}),
        throwsArgumentError,
      );
    });

    test('rejects invalid precision types', () {
      expect(
        () =>
            VisitDateSerializer.updateFields({'started_on_precision': 'month'}),
        throwsArgumentError,
      );
    });
    test('serializes exact dates with day precision by default', () {
      final fields = VisitDateSerializer.createFields(
        startedOn: DateTime(2024, 6, 15),
        endedOn: DateTime(2024, 6, 20),
      );

      expect(fields, {
        'started_on': '2024-06-15',
        'started_on_precision': 'day',
        'ended_on': '2024-06-20',
        'ended_on_precision': 'day',
      });
    });
    test('serializes complete visits with month precision', () {
      final fields = VisitDateSerializer.createFields(
        startedOn: DateTime(2024, 6, 1),
        endedOn: DateTime(2024, 8, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(fields, {
        'started_on': '2024-06-01',
        'started_on_precision': 'month',
        'ended_on': '2024-08-01',
        'ended_on_precision': 'month',
      });
    });
  });
}
