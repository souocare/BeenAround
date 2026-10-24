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
  });

  final String id;
  final int cityId;
  final String cityName;
  final String countryCode;
  final String countryName;
  final DateTime? startedOn;
  final DateTime? endedOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CityVisit.fromJson(Map<String, dynamic> json) {
    final startedOn = json['started_on'] as String?;
    final endedOn = json['ended_on'] as String?;

    return CityVisit(
      id: json['id'] as String,
      cityId: json['city_id'] as int,
      cityName: json['city_name'] as String,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
      startedOn: startedOn == null ? null : DateTime.parse(startedOn),
      endedOn: endedOn == null ? null : DateTime.parse(endedOn),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
