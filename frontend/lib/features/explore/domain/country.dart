class Country {
  const Country({
    required this.code,
    required this.name,
    required this.alpha3Code,
    required this.continent,
  });

  final String code;
  final String name;
  final String alpha3Code;
  final String continent;

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String,
      name: json['name'] as String,
      alpha3Code: json['alpha3_code'] as String,
      continent: json['continent'] as String,
    );
  }
}
