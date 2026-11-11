import '../../../core/models/partial_visit_date.dart';

import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_visit.dart';

import '../domain/trip_date_compatibility.dart';
import '../../../core/models/visit_date_precision.dart';

/// An existing visit suggested for inclusion in a Trip.
///
/// Suggestions never create or modify associations.
class TripVisitSuggestion<T> {
  const TripVisitSuggestion({required this.visit, required this.compatibility});

  final T visit;
  final TripDateCompatibility compatibility;
}

/// Finds existing country visits compatible with the Trip dates.
///
/// Already selected visits are excluded because they do not
/// need to be suggested again.
List<TripVisitSuggestion<CountryVisit>> findCompatibleCountryVisits({
  required List<CountryVisit> visits,
  required PartialVisitDate? tripStart,
  required PartialVisitDate? tripEnd,
  Set<String> excludedVisitIds = const {},
}) {
  return _findCompatibleVisits(
    visits: visits,
    tripStart: tripStart,
    tripEnd: tripEnd,
    excludedVisitIds: excludedVisitIds,
    getId: (visit) => visit.id,
    getStart: (visit) =>
        _partialDate(visit.startedOn, visit.startedOnPrecision),
    getEnd: (visit) => _partialDate(visit.endedOn, visit.endedOnPrecision),
  );
}

/// Finds existing city visits compatible with the Trip dates.
List<TripVisitSuggestion<CityVisit>> findCompatibleCityVisits({
  required List<CityVisit> visits,
  required PartialVisitDate? tripStart,
  required PartialVisitDate? tripEnd,
  Set<String> excludedVisitIds = const {},
}) {
  return _findCompatibleVisits(
    visits: visits,
    tripStart: tripStart,
    tripEnd: tripEnd,
    excludedVisitIds: excludedVisitIds,
    getId: (visit) => visit.id,
    getStart: (visit) =>
        _partialDate(visit.startedOn, visit.startedOnPrecision),
    getEnd: (visit) => _partialDate(visit.endedOn, visit.endedOnPrecision),
  );
}

List<TripVisitSuggestion<T>> _findCompatibleVisits<T>({
  required List<T> visits,
  required PartialVisitDate? tripStart,
  required PartialVisitDate? tripEnd,
  required Set<String> excludedVisitIds,
  required String Function(T) getId,
  required PartialVisitDate? Function(T) getStart,
  required PartialVisitDate? Function(T) getEnd,
}) {
  if (tripStart == null || tripEnd == null) {
    return [];
  }

  final suggestions = <TripVisitSuggestion<T>>[];

  for (final visit in visits) {
    if (excludedVisitIds.contains(getId(visit))) {
      continue;
    }

    final compatibility = evaluateTripDateCompatibility(
      tripStart: tripStart,
      tripEnd: tripEnd,
      visitStart: getStart(visit),
      visitEnd: getEnd(visit),
    );

    if (compatibility == TripDateCompatibility.none) {
      continue;
    }

    suggestions.add(
      TripVisitSuggestion(visit: visit, compatibility: compatibility),
    );
  }

  suggestions.sort((a, b) {
    final priorityComparison = _priority(
      a.compatibility,
    ).compareTo(_priority(b.compatibility));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return getId(a.visit).compareTo(getId(b.visit));
  });

  return suggestions;
}

PartialVisitDate? _partialDate(DateTime? date, VisitDatePrecision? precision) {
  if (date == null || precision == null) {
    return null;
  }

  return PartialVisitDate(date: date, precision: precision);
}

int _priority(TripDateCompatibility compatibility) {
  return switch (compatibility) {
    TripDateCompatibility.match => 0,
    TripDateCompatibility.possible => 1,
    TripDateCompatibility.none => 2,
  };
}
