import '../../../core/models/visit_date_precision.dart';
import '../../geography/domain/country_visit_date_expansion.dart';

/// Original city creation request that produced an expansion proposal.
class PendingCityVisitCreation {
  const PendingCityVisitCreation({
    required this.cityId,
    required this.startedOn,
    required this.endedOn,
    required this.startedOnPrecision,
    required this.endedOnPrecision,
    required this.countryVisitId,
    required this.expansion,
  });

  final int cityId;
  final DateTime startedOn;
  final DateTime endedOn;
  final VisitDatePrecision startedOnPrecision;
  final VisitDatePrecision endedOnPrecision;
  final String countryVisitId;
  final CountryVisitDateExpansion expansion;

  bool matches({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    required VisitDatePrecision startedOnPrecision,
    required VisitDatePrecision endedOnPrecision,
    required String countryVisitId,
  }) {
    return this.cityId == cityId &&
        this.startedOn == startedOn &&
        this.endedOn == endedOn &&
        this.startedOnPrecision == startedOnPrecision &&
        this.endedOnPrecision == endedOnPrecision &&
        this.countryVisitId == countryVisitId;
  }
}
