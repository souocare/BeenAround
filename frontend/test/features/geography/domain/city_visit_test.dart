import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

void main() {
  group('CityVisit', () {
    final baseResponse = {
      'id': 'e681d02a-b31a-4fd7-8f91-732da8742028',
      'city_id': 2267057,
      'city_name': 'Lisbon',
      'country_code': 'PT',
      'country_name': 'Portugal',
      'started_on': '2025-07-10',
      'started_on_precision': 'day',
      'ended_on': '2025-07-15',
      'ended_on_precision': 'day',
      'created_at': '2026-10-21T10:00:00',
      'updated_at': '2026-10-21T10:00:00',
    };

    test('parses a city visit with dates', () {
      final visit = CityVisit.fromJson(baseResponse);

      expect(visit.id, baseResponse['id']);
      expect(visit.cityId, 2267057);
      expect(visit.cityName, 'Lisbon');
      expect(visit.countryCode, 'PT');
      expect(visit.countryName, 'Portugal');
      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, DateTime(2025, 7, 15));
      expect(visit.createdAt, DateTime(2026, 10, 21, 10));
    });

    test('parses a city visit without dates', () {
      final visit = CityVisit.fromJson({
        ...baseResponse,
        'started_on': null,
        'ended_on': null,
      });

      expect(visit.startedOn, isNull);
      expect(visit.endedOn, isNull);
    });

    test('parses a city visit with only a start date', () {
      final visit = CityVisit.fromJson({...baseResponse, 'ended_on': null});

      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, isNull);
    });

    test('rejects malformed dates', () {
      expect(
        () =>
            CityVisit.fromJson({...baseResponse, 'started_on': 'invalid-date'}),
        throwsFormatException,
      );
    });

    test('rejects missing required fields', () {
      expect(
        () => CityVisit.fromJson({'city_id': 2267057}),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects invalid city ID types', () {
      expect(
        () => CityVisit.fromJson({...baseResponse, 'city_id': '2267057'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('preserves separate visits to the same city', () {
      final first = CityVisit.fromJson(baseResponse);

      final second = CityVisit.fromJson({
        ...baseResponse,
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'started_on': '2026-02-01',
        'ended_on': '2026-02-05',
      });

      expect(first.cityId, second.cityId);
      expect(first.id, isNot(second.id));
      expect(first.startedOn, isNot(second.startedOn));
    });
    test('parses day precision', () {
      final visit = CityVisit.fromJson(baseResponse);

      expect(visit.startedOnPrecision, VisitDatePrecision.day);
      expect(visit.endedOnPrecision, VisitDatePrecision.day);
    });

    test('parses month precision with normalized date', () {
      final visit = CityVisit.fromJson({
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
      final visit = CityVisit.fromJson({
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
      final visit = CityVisit.fromJson({
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
        () => CityVisit.fromJson({
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

      final visit = CityVisit.fromJson(response);

      expect(visit.startedOn, DateTime(2025, 7, 10));
      expect(visit.endedOn, DateTime(2025, 7, 15));
      expect(visit.startedOnPrecision, isNull);
      expect(visit.endedOnPrecision, isNull);
    });
    test('parses an explicit country visit association', () {
      final visit = CityVisit.fromJson({
        'id': 'city-visit-123',
        'city_id': 1,
        'city_name': 'Lisbon',
        'country_code': 'PT',
        'country_name': 'Portugal',
        'country_visit_id': 'country-visit-456',
        'started_on': '2025-06-12',
        'started_on_precision': 'day',
        'ended_on': '2025-06-18',
        'ended_on_precision': 'day',
        'created_at': '2025-06-20T12:00:00Z',
        'updated_at': '2025-06-20T12:00:00Z',
      });

      expect(visit.countryVisitId, 'country-visit-456');
    });
    test('supports a city visit without a country association', () {
      final visit = CityVisit.fromJson({
        'id': 'city-visit-123',
        'city_id': 1,
        'city_name': 'Lisbon',
        'country_code': 'PT',
        'country_name': 'Portugal',
        'country_visit_id': null,
        'started_on': '2025-06-12',
        'started_on_precision': 'day',
        'ended_on': '2025-06-18',
        'ended_on_precision': 'day',
        'created_at': '2025-06-20T12:00:00Z',
        'updated_at': '2025-06-20T12:00:00Z',
      });

      expect(visit.countryVisitId, isNull);
    });
    test('supports responses without country_visit_id', () {
      final visit = CityVisit.fromJson({
        'id': 'city-visit-123',
        'city_id': 1,
        'city_name': 'Lisbon',
        'country_code': 'PT',
        'country_name': 'Portugal',
        'started_on': '2025-06-12',
        'started_on_precision': 'day',
        'ended_on': '2025-06-18',
        'ended_on_precision': 'day',
        'created_at': '2025-06-20T12:00:00Z',
        'updated_at': '2025-06-20T12:00:00Z',
      });

      expect(visit.countryVisitId, isNull);
    });
  });
}
