import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisitDatePrecision', () {
    test('parses supported API values', () {
      expect(VisitDatePrecision.fromJson('day'), VisitDatePrecision.day);
      expect(VisitDatePrecision.fromJson('month'), VisitDatePrecision.month);
      expect(VisitDatePrecision.fromJson('year'), VisitDatePrecision.year);
    });

    test('serializes to API values', () {
      expect(VisitDatePrecision.day.toJson(), 'day');
      expect(VisitDatePrecision.month.toJson(), 'month');
      expect(VisitDatePrecision.year.toJson(), 'year');
    });

    test('rejects unsupported values', () {
      expect(() => VisitDatePrecision.fromJson('week'), throwsFormatException);
    });
  });
}
