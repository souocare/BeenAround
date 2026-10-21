class CountryVisitDateValidator {
  const CountryVisitDateValidator._();

  static String? validate({DateTime? startedOn, DateTime? endedOn}) {
    if (endedOn != null && startedOn == null) {
      return 'An end date requires a start date.';
    }

    if (startedOn != null && endedOn != null) {
      final startDate = DateTime(
        startedOn.year,
        startedOn.month,
        startedOn.day,
      );

      final endDate = DateTime(endedOn.year, endedOn.month, endedOn.day);

      if (endDate.isBefore(startDate)) {
        return 'End date cannot be earlier than start date.';
      }
    }

    return null;
  }
}
