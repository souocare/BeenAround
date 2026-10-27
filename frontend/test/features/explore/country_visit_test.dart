import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

void main() {
  group('CountryVisit', () {
    final baseResponse = {
      'id': 'e681d02a-b31a-4fd7-8f91-732da8742028',
      'country_code': 'PT',
      'started_on': '2025-07-10',
      'started_on_precision': 'day',
      'ended_on': '2025-07-15',
      'ended_on_precision': 'day',
      'created_at': '2026-10-21T10:00:00',
      'updated_at': '2026-10-21T10:00:00',
    };

    test('parses visit with dates', () {
      final visit = CountryVisit.fromJson(baseResponse);

      expect(visit.countryCode, 'PT');
      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, DateTime(2025, 7, 15));
      expect(visit.createdAt, DateTime(2026, 10, 21, 10));
    });

    test('parses visit without dates', () {
      final visit = CountryVisit.fromJson({
        ...baseResponse,
        'started_on': null,
        'ended_on': null,
      });

      expect(visit.startedOn, isNull);
      expect(visit.endedOn, isNull);
    });

    test('parses visit with start date only', () {
      final visit = CountryVisit.fromJson({...baseResponse, 'ended_on': null});

      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, isNull);
    });

    test('rejects malformed dates', () {
      expect(
        () => CountryVisit.fromJson({
          ...baseResponse,
          'started_on': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('rejects missing required fields', () {
      expect(
        () => CountryVisit.fromJson({'country_code': 'PT'}),
        throwsA(isA<TypeError>()),
      );
    });
    test('parses day precision', () {
      final visit = CountryVisit.fromJson(baseResponse);

      expect(visit.startedOnPrecision, VisitDatePrecision.day);
      expect(visit.endedOnPrecision, VisitDatePrecision.day);
    });

    test('parses month precision with normalized date', () {
      final visit = CountryVisit.fromJson({
        ...baseResponse,
        'started_on': '2025-07-01',
        'started_on_precision': 'month',
        'ended_on': null,
        'ended_on_precision': null,
      });

      expect(visit.startedOn, DateTime(2025, 7, 1));
      expect(visit.startedOnPrecision, VisitDatePrecision.month);
      expect(visit.endedOn, isNull);
      expect(visit.endedOnPrecision, isNull);
    });

    test('parses year precision with normalized date', () {
      final visit = CountryVisit.fromJson({
        ...baseResponse,
        'started_on': '2025-01-01',
        'started_on_precision': 'year',
        'ended_on': null,
        'ended_on_precision': null,
      });

      expect(visit.startedOn, DateTime(2025, 1, 1));
      expect(visit.startedOnPrecision, VisitDatePrecision.year);
    });

    test('parses unknown dates and precisions', () {
      final visit = CountryVisit.fromJson({
        ...baseResponse,
        'started_on': null,
        'started_on_precision': null,
        'ended_on': null,
        'ended_on_precision': null,
      });

      expect(visit.startedOn, isNull);
      expect(visit.startedOnPrecision, isNull);
      expect(visit.endedOn, isNull);
      expect(visit.endedOnPrecision, isNull);
    });

    test('rejects invalid precision', () {
      expect(
        () => CountryVisit.fromJson({
          ...baseResponse,
          'started_on_precision': 'week',
        }),
        throwsFormatException,
      );
    });

    test('parses legacy response without precision fields', () {
      final response = Map<String, dynamic>.from(baseResponse)
        ..remove('started_on_precision')
        ..remove('ended_on_precision');

      final visit = CountryVisit.fromJson(response);

      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, DateTime(2025, 7, 15));
      expect(visit.startedOnPrecision, isNull);
      expect(visit.endedOnPrecision, isNull);
    });
  });
}
