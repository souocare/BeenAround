import '../../../core/models/visit_date_precision.dart';

class CountryVisit {
  const CountryVisit({
    required this.id,
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    required this.createdAt,
    required this.updatedAt,
    this.startedOnPrecision,
    this.endedOnPrecision,
  });

  final String id;
  final String countryCode;

  final DateTime? startedOn;
  final VisitDatePrecision? startedOnPrecision;

  final DateTime? endedOn;
  final VisitDatePrecision? endedOnPrecision;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory CountryVisit.fromJson(Map<String, dynamic> json) {
    final startedOn = json['started_on'] as String?;
    final endedOn = json['ended_on'] as String?;

    final startedOnPrecision = json['started_on_precision'] as String?;
    final endedOnPrecision = json['ended_on_precision'] as String?;

    return CountryVisit(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      startedOn: startedOn == null ? null : DateTime.parse(startedOn),
      startedOnPrecision: startedOnPrecision == null
          ? null
          : VisitDatePrecision.fromJson(startedOnPrecision),
      endedOn: endedOn == null ? null : DateTime.parse(endedOn),
      endedOnPrecision: endedOnPrecision == null
          ? null
          : VisitDatePrecision.fromJson(endedOnPrecision),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
