import '../domain/country_visit.dart';

class CountryVisitSummary {
  const CountryVisitSummary({
    required this.visitCount,
    required this.lastVisitedOn,
  });

  final int visitCount;
  final DateTime? lastVisitedOn;
}

CountryVisitSummary summarizeCountryVisits(List<CountryVisit> visits) {
  DateTime? lastVisitedOn;

  for (final visit in visits) {
    // A data de fim representa a última presença conhecida.
    // Se não existir, utilizamos a data de início.
    final date = visit.endedOn ?? visit.startedOn;

    if (date == null) continue;

    if (lastVisitedOn == null || date.isAfter(lastVisitedOn)) {
      lastVisitedOn = date;
    }
  }

  return CountryVisitSummary(
    visitCount: visits.length,
    lastVisitedOn: lastVisitedOn,
  );
}
