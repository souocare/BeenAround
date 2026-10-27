import '../../../core/models/visit_date_precision.dart';

class CityVisit {
  const CityVisit({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.countryCode,
    required this.countryName,
    required this.startedOn,
    required this.endedOn,
    required this.createdAt,
    required this.updatedAt,
    this.startedOnPrecision,
    this.endedOnPrecision,
  });

  final String id;
  final int cityId;
  final String cityName;
  final String countryCode;
  final String countryName;

  final DateTime? startedOn;
  final VisitDatePrecision? startedOnPrecision;

  final DateTime? endedOn;
  final VisitDatePrecision? endedOnPrecision;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory CityVisit.fromJson(Map<String, dynamic> json) {
    final startedOn = json['started_on'] as String?;
    final endedOn = json['ended_on'] as String?;

    final startedOnPrecision = json['started_on_precision'] as String?;
    final endedOnPrecision = json['ended_on_precision'] as String?;

    return CityVisit(
      id: json['id'] as String,
      cityId: json['city_id'] as int,
      cityName: json['city_name'] as String,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
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
