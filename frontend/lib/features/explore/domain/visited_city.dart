import '../../geography/domain/city_visit.dart';

class VisitedCity {
  VisitedCity({
    required this.cityId,
    required this.cityName,
    required this.countryCode,
    required this.countryName,
    required List<CityVisit> visits,
  }) : visits = List.unmodifiable(visits);

  final int cityId;
  final String cityName;
  final String countryCode;
  final String countryName;
  final List<CityVisit> visits;

  int get visitCount => visits.length;
}
