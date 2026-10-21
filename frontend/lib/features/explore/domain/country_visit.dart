class CountryVisit {
  const CountryVisit({
    required this.id,
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String countryCode;
  final DateTime? startedOn;
  final DateTime? endedOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CountryVisit.fromJson(Map<String, dynamic> json) {
    final startedOn = json['started_on'] as String?;
    final endedOn = json['ended_on'] as String?;

    return CountryVisit(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      startedOn: startedOn == null ? null : DateTime.parse(startedOn),
      endedOn: endedOn == null ? null : DateTime.parse(endedOn),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
