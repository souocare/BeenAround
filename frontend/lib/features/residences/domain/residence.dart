import '../../../core/models/visit_date_precision.dart';

/// A historical period during which a user lived in a destination.
///
/// Residences exist independently of visits and trips.
///
/// A residence may belong to a country or to a city within that country.
/// Multiple residence periods are allowed for the same destination.
class Residence {
  const Residence({
    required this.id,
    required this.countryCode,
    required this.cityId,
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;

  final String countryCode;
  final int? cityId;

  final DateTime startedOn;
  final VisitDatePrecision startedOnPrecision;

  final DateTime endedOn;
  final VisitDatePrecision endedOnPrecision;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCityResidence => cityId != null;

  bool get isCountryResidence => cityId == null;

  factory Residence.fromJson(Map<String, dynamic> json) {
    return Residence(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      cityId: json['city_id'] as int?,
      startedOn: DateTime.parse(json['started_on'] as String),
      startedOnPrecision: VisitDatePrecision.fromJson(
        json['started_on_precision'] as String,
      ),
      endedOn: DateTime.parse(json['ended_on'] as String),
      endedOnPrecision: VisitDatePrecision.fromJson(
        json['ended_on_precision'] as String,
      ),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
