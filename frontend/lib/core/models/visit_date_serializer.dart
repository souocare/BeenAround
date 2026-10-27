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
    required DateTime? startedOn,
    required DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    final fields = <String, dynamic>{
      'started_on': formatDate(startedOn),
      'ended_on': formatDate(endedOn),
    };

    if (startedOnPrecision != null) {
      fields['started_on_precision'] = startedOnPrecision.toJson();
    }

    if (endedOnPrecision != null) {
      fields['ended_on_precision'] = endedOnPrecision.toJson();
    }

    return fields;
  }

  static Map<String, dynamic> updateFields(Map<String, dynamic> changes) {
    const dateFields = {'started_on', 'ended_on'};
    const precisionFields = {'started_on_precision', 'ended_on_precision'};

    final result = <String, dynamic>{};

    for (final entry in changes.entries) {
      if (dateFields.contains(entry.key)) {
        final value = entry.value;

        if (value != null && value is! DateTime) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a DateTime or null.',
          );
        }

        result[entry.key] = formatDate(value as DateTime?);
      } else if (precisionFields.contains(entry.key)) {
        final value = entry.value;

        if (value != null && value is! VisitDatePrecision) {
          throw ArgumentError.value(
            value,
            entry.key,
            'Expected a VisitDatePrecision or null.',
          );
        }

        result[entry.key] = (value as VisitDatePrecision?)?.toJson();
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
