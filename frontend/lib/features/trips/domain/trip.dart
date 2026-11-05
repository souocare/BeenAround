import '../../../core/models/partial_visit_date.dart';
import '../../../core/models/visit_date_precision.dart';

/// A user-owned journey.
///
/// Trips organize independent travel records without owning them.
///
/// Country visits, city visits and flights will be associated
/// through dedicated relationships in future milestones.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.description,
    required this.startedOn,
    required this.endedOn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;

  final PartialVisitDate? startedOn;
  final PartialVisitDate? endedOn;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasDates => startedOn != null || endedOn != null;

  bool get hasCompleteDateRange => startedOn != null && endedOn != null;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      startedOn: _parsePartialDate(
        json,
        dateField: 'started_on',
        precisionField: 'started_on_precision',
      ),
      endedOn: _parsePartialDate(
        json,
        dateField: 'ended_on',
        precisionField: 'ended_on_precision',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static PartialVisitDate? _parsePartialDate(
    Map<String, dynamic> json, {
    required String dateField,
    required String precisionField,
  }) {
    final rawDate = json[dateField];
    final rawPrecision = json[precisionField];

    if (rawDate == null && rawPrecision == null) {
      return null;
    }

    if (rawDate is! String || rawPrecision is! String) {
      throw FormatException('Invalid Trip date or precision: $dateField.');
    }

    final precision = VisitDatePrecision.fromJson(rawPrecision);

    final date = DateTime.tryParse(rawDate);

    if (date == null) {
      throw FormatException('Invalid Trip date: $dateField.');
    }

    // The API must return canonical dates.
    //
    // Month precision: YYYY-MM-01
    // Year precision:  YYYY-01-01
    if (precision == VisitDatePrecision.month && date.day != 1) {
      throw FormatException('Non-canonical month date: $dateField.');
    }

    if (precision == VisitDatePrecision.year &&
        (date.month != 1 || date.day != 1)) {
      throw FormatException('Non-canonical year date: $dateField.');
    }

    return PartialVisitDate(date: date, precision: precision);
  }
}
