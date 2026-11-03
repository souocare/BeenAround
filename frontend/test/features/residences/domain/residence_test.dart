import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

void main() {
  Map<String, dynamic> residenceJson({int? cityId, String? note}) {
    return {
      'id': 'residence-1',
      'country_code': 'PT',
      'city_id': cityId,
      'started_on': '2020-03-01',
      'started_on_precision': 'month',
      'ended_on': '2023-08-01',
      'ended_on_precision': 'month',
      'note': note,
      'created_at': '2026-11-03T10:00:00Z',
      'updated_at': '2026-11-03T10:00:00Z',
    };
  }

  group('Residence', () {
    test('parses a country residence', () {
      final residence = Residence.fromJson(residenceJson());

      expect(residence.id, 'residence-1');
      expect(residence.countryCode, 'PT');
      expect(residence.cityId, isNull);

      expect(residence.isCountryResidence, isTrue);
      expect(residence.isCityResidence, isFalse);

      expect(residence.startedOn, DateTime(2020, 3));

      expect(residence.endedOn, DateTime(2023, 8));

      expect(residence.startedOnPrecision, VisitDatePrecision.month);

      expect(residence.endedOnPrecision, VisitDatePrecision.month);

      expect(residence.note, isNull);
    });

    test('parses a city residence', () {
      final residence = Residence.fromJson(residenceJson(cityId: 123));

      expect(residence.cityId, 123);
      expect(residence.isCityResidence, isTrue);
      expect(residence.isCountryResidence, isFalse);
    });

    test('preserves an optional note', () {
      final residence = Residence.fromJson(
        residenceJson(note: 'Studied here during university.'),
      );

      expect(residence.note, 'Studied here during university.');
    });

    test('rejects missing required dates', () {
      final json = residenceJson();

      json.remove('started_on');

      expect(() => Residence.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('rejects unsupported date precision', () {
      final json = residenceJson();

      json['started_on_precision'] = 'invalid';

      expect(() => Residence.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
