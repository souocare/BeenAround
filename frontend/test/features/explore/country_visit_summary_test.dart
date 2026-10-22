import 'package:beenaround/features/explore/application/country_visit_summary.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter_test/flutter_test.dart';

CountryVisit visit({
  required String id,
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CountryVisit(
    id: id,
    countryCode: 'PT',
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('summarizeCountryVisits', () {
    test('counts visits without dates', () {
      final summary = summarizeCountryVisits([visit(id: '1'), visit(id: '2')]);

      expect(summary.visitCount, 2);
      expect(summary.lastVisitedOn, isNull);
    });

    test('uses end date when available', () {
      final summary = summarizeCountryVisits([
        visit(
          id: '1',
          startedOn: DateTime(2025, 1, 10),
          endedOn: DateTime(2025, 1, 20),
        ),
      ]);

      expect(summary.lastVisitedOn, DateTime(2025, 1, 20));
    });

    test('uses start date when end date is missing', () {
      final summary = summarizeCountryVisits([
        visit(id: '1', startedOn: DateTime(2025, 3, 12)),
      ]);

      expect(summary.lastVisitedOn, DateTime(2025, 3, 12));
    });

    test('finds the most recent visit regardless of list order', () {
      final summary = summarizeCountryVisits([
        visit(id: '1', startedOn: DateTime(2026, 1, 10)),
        visit(id: '2', startedOn: DateTime(2024, 6, 10)),
        visit(id: '3', startedOn: DateTime(2025, 8, 20)),
      ]);

      expect(summary.visitCount, 3);
      expect(summary.lastVisitedOn, DateTime(2026, 1, 10));
    });

    test('ignores visits without dates when determining recency', () {
      final summary = summarizeCountryVisits([
        visit(id: '1'),
        visit(id: '2', startedOn: DateTime(2025, 5, 1)),
      ]);

      expect(summary.visitCount, 2);
      expect(summary.lastVisitedOn, DateTime(2025, 5, 1));
    });

    test('handles empty visit lists', () {
      final summary = summarizeCountryVisits([]);

      expect(summary.visitCount, 0);
      expect(summary.lastVisitedOn, isNull);
    });
  });
}
