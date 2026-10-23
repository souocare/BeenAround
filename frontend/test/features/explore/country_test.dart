import 'package:beenaround/features/explore/domain/country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Country', () {
    test('parses country API response', () {
      final country = Country.fromJson({
        'code': 'PT',
        'name': 'Portugal',
        'alpha3_code': 'PRT',
        'continent': 'Europe',
      });

      expect(country.code, 'PT');
      expect(country.name, 'Portugal');
      expect(country.alpha3Code, 'PRT');
      expect(country.continent, 'Europe');
    });

    test('parses countries from different continents', () {
      final country = Country.fromJson({
        'code': 'LK',
        'name': 'Sri Lanka',
        'alpha3_code': 'LKA',
        'continent': 'Asia',
      });

      expect(country.code, 'LK');
      expect(country.continent, 'Asia');
    });

    test('rejects missing required fields', () {
      expect(
        () => Country.fromJson({'code': 'PT', 'name': 'Portugal'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects missing continent', () {
      expect(
        () => Country.fromJson({
          'code': 'PT',
          'name': 'Portugal',
          'alpha3_code': 'PRT',
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects null continent', () {
      expect(
        () => Country.fromJson({
          'code': 'PT',
          'name': 'Portugal',
          'alpha3_code': 'PRT',
          'continent': null,
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
