import '../../../core/models/partial_visit_date.dart';
import '../../../core/models/visit_date_precision.dart';
import '../../../core/models/visit_date_serializer.dart';

import 'trip_status.dart';

/// Validated input for creating or replacing the editable fields of a Trip.
///
/// The same payload can be used by POST and PATCH.
///
/// Sending null date fields explicitly clears existing dates during PATCH.
class TripInput {
  const TripInput({
    required this.name,
    this.description,
    this.startedOn,
    this.endedOn,
  });

  final String name;
  final String? description;

  final PartialVisitDate? startedOn;
  final PartialVisitDate? endedOn;

  /// Validate the input and produce the REST API payload.
  ///
  /// Date precision is preserved without inventing unknown components.
  Map<String, dynamic> toJson() {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Trip name cannot be empty.');
    }

    if (normalizedName.length > 160) {
      throw ArgumentError.value(
        name,
        'name',
        'Trip name cannot exceed 160 characters.',
      );
    }

    final normalizedDescription = description?.trim();

    if (normalizedDescription != null && normalizedDescription.length > 5000) {
      throw ArgumentError.value(
        description,
        'description',
        'Trip description cannot exceed 5000 characters.',
      );
    }

    final start = _normalizePartialDate(startedOn);
    final end = _normalizePartialDate(endedOn);

    if (start != null && end != null) {
      final startBounds = tripDateBounds(start);
      final endBounds = tripDateBounds(end);

      if (startBounds.earliest.isAfter(endBounds.latest)) {
        throw ArgumentError('Trip end date cannot be earlier than start date.');
      }
    }

    return {
      'name': normalizedName,
      'description': normalizedDescription?.isEmpty == true
          ? null
          : normalizedDescription,
      'started_on': VisitDateSerializer.formatDate(start?.date),
      'started_on_precision': start?.precision.toJson(),
      'ended_on': VisitDateSerializer.formatDate(end?.date),
      'ended_on_precision': end?.precision.toJson(),
    };
  }

  static PartialVisitDate? _normalizePartialDate(PartialVisitDate? value) {
    if (value == null) {
      return null;
    }

    final date = value.date;

    final normalizedDate = switch (value.precision) {
      VisitDatePrecision.day => DateTime(date.year, date.month, date.day),
      VisitDatePrecision.month => DateTime(date.year, date.month, 1),
      VisitDatePrecision.year => DateTime(date.year, 1, 1),
    };

    return PartialVisitDate(date: normalizedDate, precision: value.precision);
  }
}
