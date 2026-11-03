import '../../../core/models/visit_date_precision.dart';

/// Input for registering a historical residence.
///
/// Residence dates are mandatory and must use day or month precision.
/// The backend remains responsible for canonical date and overlap validation.
class ResidenceInput {
  ResidenceInput({
    required this.countryCode,
    this.cityId,
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
    this.note,
  }) {
    final code = countryCode.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'Expected a two-letter country code.',
      );
    }

    if (cityId != null && cityId! <= 0) {
      throw ArgumentError.value(
        cityId,
        'cityId',
        'Expected a positive city ID.',
      );
    }

    if (startedOnPrecision == VisitDatePrecision.year ||
        endedOnPrecision == VisitDatePrecision.year) {
      throw ArgumentError('Residence dates require day or month precision.');
    }

    if (note != null && note!.length > 1000) {
      throw ArgumentError.value(
        note,
        'note',
        'A residence note cannot exceed 1000 characters.',
      );
    }
  }

  final String countryCode;
  final int? cityId;

  final DateTime startedOn;
  final VisitDatePrecision startedOnPrecision;

  final DateTime endedOn;
  final VisitDatePrecision endedOnPrecision;

  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'country_code': countryCode.trim().toUpperCase(),
      'city_id': cityId,
      'started_on': serializeDate(startedOn, startedOnPrecision),
      'started_on_precision': startedOnPrecision.toJson(),
      'ended_on': serializeDate(endedOn, endedOnPrecision),
      'ended_on_precision': endedOnPrecision.toJson(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
    };
  }

  static String serializeDate(DateTime value, VisitDatePrecision precision) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');

    final day = precision == VisitDatePrecision.month
        ? '01'
        : value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
