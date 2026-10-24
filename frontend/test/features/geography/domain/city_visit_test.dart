import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CityVisit', () {
    final baseResponse = {
      'id': 'e681d02a-b31a-4fd7-8f91-732da8742028',
      'city_id': 2267057,
      'city_name': 'Lisbon',
      'country_code': 'PT',
      'country_name': 'Portugal',
      'started_on': '2025-07-10',
      'ended_on': '2025-07-15',
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
  });
}
