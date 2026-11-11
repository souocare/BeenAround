import '../../../core/models/partial_visit_date.dart';
import '../../../core/models/visit_date_precision.dart';

import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_visit.dart';

import 'trip.dart';
import 'trip_status.dart';

/// Describes the temporal compatibility between a Trip and a visit.
///
/// This is advisory only. Compatibility never implies that records
/// should be associated automatically.
enum TripDateCompatibility {
  /// An overlap is guaranteed by the known date boundaries.
  match,

  /// An overlap is possible, but cannot be guaranteed.
  possible,

  /// No overlap is possible, or there is insufficient information.
  none,
}

/// Compares two potentially imprecise date ranges.
///
/// Both start and end boundaries must be present. Missing boundaries
/// are intentionally not interpreted as open-ended travel periods.
///
/// A partial start date represents a set of possible start days.
/// A partial end date represents a set of possible end days.
TripDateCompatibility evaluateTripDateCompatibility({
  required PartialVisitDate? tripStart,
  required PartialVisitDate? tripEnd,
  required PartialVisitDate? visitStart,
  required PartialVisitDate? visitEnd,
}) {
  if (tripStart == null ||
      tripEnd == null ||
      visitStart == null ||
      visitEnd == null) {
    return TripDateCompatibility.none;
  }

  final tripStartBounds = tripDateBounds(tripStart);
  final tripEndBounds = tripDateBounds(tripEnd);

  final visitStartBounds = tripDateBounds(visitStart);
  final visitEndBounds = tripDateBounds(visitEnd);

  // Reject impossible date ranges.
  if (tripStartBounds.earliest.isAfter(tripEndBounds.latest) ||
      visitStartBounds.earliest.isAfter(visitEndBounds.latest)) {
    return TripDateCompatibility.none;
  }

  // The widest possible intervals do not intersect.
  //
  // Therefore, no interpretation of the partial dates can overlap.
  if (tripEndBounds.latest.isBefore(visitStartBounds.earliest) ||
      visitEndBounds.latest.isBefore(tripStartBounds.earliest)) {
    return TripDateCompatibility.none;
  }

  // Even under the latest possible start and earliest possible end,
  // the two ranges must overlap.
  final guaranteedOverlap =
      !tripStartBounds.latest.isAfter(visitEndBounds.earliest) &&
      !visitStartBounds.latest.isAfter(tripEndBounds.earliest);

  if (guaranteedOverlap) {
    return TripDateCompatibility.match;
  }

  return TripDateCompatibility.possible;
}

/// Evaluates a CountryVisit against a Trip.
TripDateCompatibility countryVisitTripCompatibility({
  required Trip trip,
  required CountryVisit visit,
}) {
  return evaluateTripDateCompatibility(
    tripStart: trip.startedOn,
    tripEnd: trip.endedOn,
    visitStart: _partialDate(visit.startedOn, visit.startedOnPrecision),
    visitEnd: _partialDate(visit.endedOn, visit.endedOnPrecision),
  );
}

/// Evaluates a CityVisit against a Trip.
TripDateCompatibility cityVisitTripCompatibility({
  required Trip trip,
  required CityVisit visit,
}) {
  return evaluateTripDateCompatibility(
    tripStart: trip.startedOn,
    tripEnd: trip.endedOn,
    visitStart: _partialDate(visit.startedOn, visit.startedOnPrecision),
    visitEnd: _partialDate(visit.endedOn, visit.endedOnPrecision),
  );
}

PartialVisitDate? _partialDate(DateTime? date, VisitDatePrecision? precision) {
  if (date == null || precision == null) {
    return null;
  }

  return PartialVisitDate(date: date, precision: precision);
}
