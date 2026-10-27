import 'visit_date_precision.dart';

class PartialVisitDate {
  const PartialVisitDate({required this.date, required this.precision});

  final DateTime date;
  final VisitDatePrecision precision;

  @override
  bool operator ==(Object other) {
    return other is PartialVisitDate &&
        other.date == date &&
        other.precision == precision;
  }

  @override
  int get hashCode => Object.hash(date, precision);
}
