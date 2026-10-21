import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryVisit', () {
    final baseResponse = {
      'id': 'e681d02a-b31a-4fd7-8f91-732da8742028',
      'country_code': 'PT',
      'started_on': '2025-07-10',
      'ended_on': '2025-07-15',
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
  });
}
