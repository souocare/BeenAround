import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const countryVisitId = '550e8400-e29b-41d4-a716-446655440001';

  final response = <String, dynamic>{
    'country_visit_id': countryVisitId,
    'current': {
      'started_on': '2025-06-01',
      'started_on_precision': 'month',
      'ended_on': '2025-06-15',
      'ended_on_precision': 'day',
    },
    'proposed': {
      'started_on': '2025-06-01',
      'started_on_precision': 'month',
      'ended_on': '2025-06-18',
      'ended_on_precision': 'day',
    },
  };

  group('CountryVisitDateState', () {
    test('parses dates while preserving precision', () {
      final state = CountryVisitDateState.fromJson(
        Map<String, dynamic>.from(response['current'] as Map),
      );

      expect(state.startedOn, DateTime(2025, 6, 1));
      expect(state.startedOnPrecision, VisitDatePrecision.month);
      expect(state.endedOn, DateTime(2025, 6, 15));
      expect(state.endedOnPrecision, VisitDatePrecision.day);
    });

    test('serializes the original date precision', () {
      final state = CountryVisitDateState.fromJson(
        Map<String, dynamic>.from(response['current'] as Map),
      );

      expect(state.toJson(), response['current']);
    });

    test('rejects unsupported precision values', () {
      expect(
        () => CountryVisitDateState.fromJson({
          'started_on': '2025-06-01',
          'started_on_precision': 'week',
          'ended_on': '2025-06-15',
          'ended_on_precision': 'day',
        }),
        throwsFormatException,
      );
    });
  });

  group('CountryVisitDateExpansion', () {
    test('parses a backend expansion proposal', () {
      final expansion = CountryVisitDateExpansion.fromJson(response);

      expect(expansion.countryVisitId, countryVisitId);
      expect(expansion.current.endedOn, DateTime(2025, 6, 15));
      expect(expansion.proposed.endedOn, DateTime(2025, 6, 18));
    });

    test('builds the exact confirmation payload', () {
      final expansion = CountryVisitDateExpansion.fromJson(response);

      expect(expansion.toConfirmationJson(), {
        'expected': response['current'],
        'proposed': response['proposed'],
      });
    });

    test('does not alter the source date states', () {
      final expansion = CountryVisitDateExpansion.fromJson(response);

      final confirmation = expansion.toConfirmationJson();

      (confirmation['proposed'] as Map<String, dynamic>)['ended_on'] =
          '2025-06-25';

      expect(expansion.proposed.endedOn, DateTime(2025, 6, 18));

      expect(expansion.toConfirmationJson()['proposed'], response['proposed']);
    });
  });

  group('CountryVisitDateExpansionRequired', () {
    test('exposes the structured expansion proposal', () {
      final expansion = CountryVisitDateExpansion.fromJson(response);

      final exception = CountryVisitDateExpansionRequired(expansion);

      expect(exception.expansion.countryVisitId, countryVisitId);
      expect(exception.expansion.proposed.endedOn, DateTime(2025, 6, 18));
    });
  });
}
