import '../../../core/models/visit_date_precision.dart';
import 'residence_input.dart';

/// Explicit changes to an existing historical residence.
///
/// Omitted fields preserve their stored values.
/// An explicitly provided null note clears the existing note.
class ResidenceChanges {
  ResidenceChanges({
    this.countryCode,
    this.cityId,
    this.startedOn,
    this.startedOnPrecision,
    this.endedOn,
    this.endedOnPrecision,
    this.note,
    this.updateNote = false,
    this.updateCityId = false,
  }) {
    if (!hasChanges) {
      throw ArgumentError('At least one residence change is required.');
    }

    if ((startedOn == null) != (startedOnPrecision == null)) {
      throw ArgumentError(
        'Start date and precision must be provided together.',
      );
    }

    if ((endedOn == null) != (endedOnPrecision == null)) {
      throw ArgumentError('End date and precision must be provided together.');
    }

    if (startedOnPrecision == VisitDatePrecision.year ||
        endedOnPrecision == VisitDatePrecision.year) {
      throw ArgumentError('Residence dates require day or month precision.');
    }

    if (updateNote && note != null && note!.length > 1000) {
      throw ArgumentError.value(
        note,
        'note',
        'A residence note cannot exceed 1000 characters.',
      );
    }

    if (updateCityId && cityId != null && cityId! <= 0) {
      throw ArgumentError.value(
        cityId,
        'cityId',
        'Expected a positive city ID.',
      );
    }

    if (countryCode != null &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode!.trim().toUpperCase())) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Expected a two-letter country code.',
      );
    }
  }

  final String? countryCode;

  /// The selected city, or null when changing to a country residence.
  final int? cityId;

  /// Distinguishes omitted cityId from an explicit null.
  final bool updateCityId;

  final DateTime? startedOn;
  final VisitDatePrecision? startedOnPrecision;

  final DateTime? endedOn;
  final VisitDatePrecision? endedOnPrecision;

  final String? note;

  /// Distinguishes an omitted note from an explicit null.
  final bool updateNote;

  bool get hasChanges =>
      countryCode != null ||
      updateCityId ||
      startedOn != null ||
      endedOn != null ||
      updateNote;

  bool get changesLocationOrDates =>
      countryCode != null ||
      updateCityId ||
      startedOn != null ||
      endedOn != null;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{};

    if (countryCode != null) {
      payload['country_code'] = countryCode!.trim().toUpperCase();
    }

    if (updateCityId) {
      payload['city_id'] = cityId;
    }

    if (startedOn != null) {
      payload['started_on'] = ResidenceInput.serializeDate(
        startedOn!,
        startedOnPrecision!,
      );
      payload['started_on_precision'] = startedOnPrecision!.toJson();
    }

    if (endedOn != null) {
      payload['ended_on'] = ResidenceInput.serializeDate(
        endedOn!,
        endedOnPrecision!,
      );
      payload['ended_on_precision'] = endedOnPrecision!.toJson();
    }

    if (updateNote) {
      payload['note'] = note?.trim().isEmpty == true ? null : note?.trim();
    }

    return payload;
  }
}
