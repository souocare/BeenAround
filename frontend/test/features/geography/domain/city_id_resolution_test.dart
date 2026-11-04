import 'package:beenaround/features/geography/domain/city_id_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCityResolutionIds', () {
    test('preserves requested order', () {
      expect(normalizeCityResolutionIds([104, 100, 102]), [104, 100, 102]);
    });

    test('removes duplicate IDs', () {
      expect(normalizeCityResolutionIds([100, 104, 100, 102]), [100, 104, 102]);
    });

    test('accepts empty lists', () {
      expect(normalizeCityResolutionIds([]), isEmpty);
    });

    test('rejects zero IDs', () {
      expect(() => normalizeCityResolutionIds([0]), throwsArgumentError);
    });

    test('rejects negative IDs', () {
      expect(() => normalizeCityResolutionIds([-1]), throwsArgumentError);
    });

    test('accepts exactly 200 IDs', () {
      final result = normalizeCityResolutionIds(
        List.generate(200, (index) => index + 1),
      );

      expect(result, hasLength(200));
    });

    test('rejects more than 200 IDs', () {
      expect(
        () => normalizeCityResolutionIds(
          List.generate(201, (index) => index + 1),
        ),
        throwsArgumentError,
      );
    });

    test('applies limit before deduplication', () {
      expect(
        () => normalizeCityResolutionIds(List.filled(201, 100)),
        throwsArgumentError,
      );
    });

    test('returns an immutable list', () {
      final result = normalizeCityResolutionIds([100]);

      expect(() => result.clear(), throwsUnsupportedError);
    });
  });
}
