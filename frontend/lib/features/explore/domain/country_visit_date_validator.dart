import '../../../core/models/visit_date_precision.dart';

class CountryVisitDateValidator {
  const CountryVisitDateValidator._();

  static String? validate({
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    if (startedOn == null && startedOnPrecision != null) {
      return 'A start date precision requires a start date.';
    }

    if (endedOn == null && endedOnPrecision != null) {
      return 'An end date precision requires an end date.';
    }

    if (startedOn == null || endedOn == null) {
      return null;
    }

    final startBounds = _bounds(
      startedOn,
      startedOnPrecision ?? VisitDatePrecision.day,
    );

    final endBounds = _bounds(
      endedOn,
      endedOnPrecision ?? VisitDatePrecision.day,
    );

    if (endBounds.$2.isBefore(startBounds.$1)) {
      return 'End date cannot be earlier than start date.';
    }

    return null;
  }

  static (DateTime, DateTime) _bounds(
    DateTime date,
    VisitDatePrecision precision,
  ) {
    return switch (precision) {
      VisitDatePrecision.day => (
        DateTime(date.year, date.month, date.day),
        DateTime(date.year, date.month, date.day),
      ),
      VisitDatePrecision.month => (
        DateTime(date.year, date.month, 1),
        DateTime(date.year, date.month + 1, 0),
      ),
      VisitDatePrecision.year => (
        DateTime(date.year, 1, 1),
        DateTime(date.year, 12, 31),
      ),
    };
  }
}
