import '../../../core/models/partial_visit_date.dart';

import '../domain/trip.dart';
import '../domain/trip_date_compatibility.dart';

/// A Trip suggested because its dates may overlap with a visit.
///
/// Suggestions are advisory only and never create associations.
class TripSuggestion {
  const TripSuggestion({required this.trip, required this.compatibility});

  final Trip trip;
  final TripDateCompatibility compatibility;
}

/// Returns Trips whose dates are compatible with a visit.
///
/// Existing associations can be excluded using [excludedTripIds].
///
/// Results are ordered by compatibility, then Trip name and ID.
///
/// No repository calls or persistence operations are performed.
List<TripSuggestion> findCompatibleTrips({
  required List<Trip> trips,
  required PartialVisitDate? visitStart,
  required PartialVisitDate? visitEnd,
  Set<String> excludedTripIds = const {},
}) {
  if (visitStart == null || visitEnd == null) {
    return const [];
  }

  final suggestions = <TripSuggestion>[];

  for (final trip in trips) {
    if (excludedTripIds.contains(trip.id)) {
      continue;
    }

    final compatibility = evaluateTripDateCompatibility(
      tripStart: trip.startedOn,
      tripEnd: trip.endedOn,
      visitStart: visitStart,
      visitEnd: visitEnd,
    );

    if (compatibility == TripDateCompatibility.none) {
      continue;
    }

    suggestions.add(TripSuggestion(trip: trip, compatibility: compatibility));
  }

  suggestions.sort((a, b) {
    final compatibilityOrder = _priority(
      a.compatibility,
    ).compareTo(_priority(b.compatibility));

    if (compatibilityOrder != 0) {
      return compatibilityOrder;
    }

    final nameOrder = a.trip.name.toLowerCase().compareTo(
      b.trip.name.toLowerCase(),
    );

    if (nameOrder != 0) {
      return nameOrder;
    }

    return a.trip.id.compareTo(b.trip.id);
  });

  return suggestions;
}

int _priority(TripDateCompatibility compatibility) {
  switch (compatibility) {
    case TripDateCompatibility.match:
      return 0;

    case TripDateCompatibility.possible:
      return 1;

    case TripDateCompatibility.none:
      return 2;
  }
}
