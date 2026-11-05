import '../../../core/models/partial_visit_date.dart';
import '../../../core/models/visit_date_precision.dart';

import 'trip.dart';

enum TripStatus { upcoming, ongoing, completed, undated }

/// Inclusive calendar-date interval represented by a partial date.
class TripDateBounds {
  const TripDateBounds({required this.earliest, required this.latest});

  final DateTime earliest;
  final DateTime latest;
}

/// Resolve the possible calendar dates represented by a partial date.
TripDateBounds tripDateBounds(PartialVisitDate value) {
  final date = value.date;

  switch (value.precision) {
    case VisitDatePrecision.day:
      final exact = DateTime(date.year, date.month, date.day);

      return TripDateBounds(earliest: exact, latest: exact);

    case VisitDatePrecision.month:
      return TripDateBounds(
        earliest: DateTime(date.year, date.month, 1),
        latest: DateTime(date.year, date.month + 1, 0),
      );

    case VisitDatePrecision.year:
      return TripDateBounds(
        earliest: DateTime(date.year, 1, 1),
        latest: DateTime(date.year, 12, 31),
      );
  }
}

/// Determine a Trip's temporal status without assuming unknown dates.
///
/// A status is returned only when the available information proves it.
/// Otherwise the result is undated.
TripStatus resolveTripStatus(Trip trip, {DateTime? now}) {
  final current = now ?? DateTime.now();

  final today = DateTime(current.year, current.month, current.day);

  final start = trip.startedOn;
  final end = trip.endedOn;

  final startBounds = start == null ? null : tripDateBounds(start);
  final endBounds = end == null ? null : tripDateBounds(end);

  // The earliest possible start is still in the future.
  if (startBounds != null && startBounds.earliest.isAfter(today)) {
    return TripStatus.upcoming;
  }

  // The latest possible end has already passed.
  if (endBounds != null && endBounds.latest.isBefore(today)) {
    return TripStatus.completed;
  }

  // Both boundaries must be known to establish that a Trip
  // is definitely ongoing.
  //
  // The latest possible start must have passed, and the
  // earliest possible end must not have passed.
  if (startBounds != null &&
      endBounds != null &&
      !startBounds.latest.isAfter(today) &&
      !endBounds.earliest.isBefore(today)) {
    return TripStatus.ongoing;
  }

  return TripStatus.undated;
}
