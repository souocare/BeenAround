enum VisitDatePrecision {
  day,
  month,
  year;

  static VisitDatePrecision fromJson(String value) {
    return switch (value) {
      'day' => VisitDatePrecision.day,
      'month' => VisitDatePrecision.month,
      'year' => VisitDatePrecision.year,
      _ => throw FormatException('Invalid visit date precision: $value'),
    };
  }

  String toJson() => name;
}
