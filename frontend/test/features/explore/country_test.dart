import 'package:beenaround/features/explore/domain/country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Country', () {
    test('parses country API response', () {
      final country = Country.fromJson({
        'code': 'PT',
        'name': 'Portugal',
        'alpha3_code': 'PRT',
      });

      expect(country.code, 'PT');
      expect(country.name, 'Portugal');
      expect(country.alpha3Code, 'PRT');
    });

    test('rejects missing required fields', () {
      expect(
        () => Country.fromJson({'code': 'PT', 'name': 'Portugal'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
