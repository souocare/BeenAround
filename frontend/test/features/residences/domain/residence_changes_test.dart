import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResidenceChanges', () {
    test('updates only the note', () {
      final changes = ResidenceChanges(
        note: '  Updated note.  ',
        updateNote: true,
      );

      expect(changes.toJson(), {'note': 'Updated note.'});

      expect(changes.changesLocationOrDates, isFalse);
    });

    test('removes the note with explicit null', () {
      final changes = ResidenceChanges(note: null, updateNote: true);

      expect(changes.toJson(), {'note': null});
    });

    test('omits unchanged notes', () {
      final changes = ResidenceChanges(
        endedOn: DateTime(2024, 6),
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(changes.toJson().containsKey('note'), isFalse);
    });

    test('serializes changed month dates canonically', () {
      final changes = ResidenceChanges(
        endedOn: DateTime(2024, 6, 23),
        endedOnPrecision: VisitDatePrecision.month,
      );

      expect(changes.toJson(), {
        'ended_on': '2024-06-01',
        'ended_on_precision': 'month',
      });
    });

    test('supports explicitly clearing cityId', () {
      final changes = ResidenceChanges(cityId: null, updateCityId: true);

      expect(changes.toJson(), {'city_id': null});
    });

    test('rejects an empty PATCH', () {
      expect(() => ResidenceChanges(), throwsArgumentError);
    });

    test('rejects dates without precision', () {
      expect(
        () => ResidenceChanges(startedOn: DateTime(2020)),
        throwsArgumentError,
      );
    });

    test('rejects year precision', () {
      expect(
        () => ResidenceChanges(
          endedOn: DateTime(2024),
          endedOnPrecision: VisitDatePrecision.year,
        ),
        throwsArgumentError,
      );
    });
  });
}
