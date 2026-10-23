class City {
  const City({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.name,
    required this.asciiName,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.featureCode,
  });

  final int id;
  final String countryCode;
  final String countryName;
  final String name;
  final String? asciiName;
  final double latitude;
  final double longitude;
  final int? population;
  final String featureCode;
}
