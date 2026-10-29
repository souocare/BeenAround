import 'visit_date_precision.dart';

class VisitDateSerializer {
  const VisitDateSerializer._();

  static String? formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static Map<String, dynamic> createFields({
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) {
    return {
      'started_on': formatDate(startedOn),
      'started_on_precision': startedOnPrecision.toJson(),
      'ended_on': formatDate(endedOn),
      'ended_on_precision': endedOnPrecision.toJson(),
    };
  }

  static Map<String, dynamic> updateFields(Map<String, dynamic> changes) {
    const dateFields = {'started_on', 'ended_on'};
    const precisionFields = {'started_on_precision', 'ended_on_precision'};

    final result = <String, dynamic>{};

    for (final entry in changes.entries) {
      if (dateFields.contains(entry.key)) {
        final value = entry.value;

        if (value is! DateTime) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a non-null DateTime.',
          );
        }

        result[entry.key] = formatDate(value);
      } else if (precisionFields.contains(entry.key)) {
        final value = entry.value;

        if (value is! VisitDatePrecision) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a non-null VisitDatePrecision.',
          );
        }

        result[entry.key] = value.toJson();
      } else {
        throw ArgumentError.value(
          entry.key,
          'changes',
          'Unsupported visit date field.',
        );
      }
    }

    return result;
  }
}
