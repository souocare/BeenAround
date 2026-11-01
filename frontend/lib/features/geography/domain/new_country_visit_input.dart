import '../../../core/models/visit_date_precision.dart';

/// User-provided dates for a country visit created together with a city visit.
///
/// The country code is determined by the backend from the selected city.
/// This object never represents an automatically inferred country visit.
class NewCountryVisitInput {
  const NewCountryVisitInput({
    required this.startedOn,
    required this.endedOn,
    this.startedOnPrecision = VisitDatePrecision.day,
    this.endedOnPrecision = VisitDatePrecision.day,
  });

  final DateTime startedOn;
  final VisitDatePrecision startedOnPrecision;

  final DateTime endedOn;
  final VisitDatePrecision endedOnPrecision;
}
