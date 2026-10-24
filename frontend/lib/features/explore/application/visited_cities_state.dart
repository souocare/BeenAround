import '../../geography/domain/city_visit.dart';
import '../domain/visited_city.dart';

enum VisitedCitiesPhase { initial, loading, ready, failure }

class VisitedCitiesState {
  const VisitedCitiesState({
    this.phase = VisitedCitiesPhase.initial,
    this.visits = const [],
    this.errorMessage,
  });

  final VisitedCitiesPhase phase;
  final List<CityVisit> visits;
  final String? errorMessage;

  bool get hasData => phase == VisitedCitiesPhase.ready;

  int get totalVisits => visits.length;

  int get visitedCityCount => visitedCities.length;

  List<VisitedCity> get visitedCities {
    final grouped = <int, List<CityVisit>>{};

    for (final visit in visits) {
      grouped.putIfAbsent(visit.cityId, () => []).add(visit);
    }

    final cities = grouped.values.map((cityVisits) {
      final first = cityVisits.first;

      return VisitedCity(
        cityId: first.cityId,
        cityName: first.cityName,
        countryCode: first.countryCode,
        countryName: first.countryName,
        visits: cityVisits,
      );
    }).toList();

    cities.sort((a, b) {
      final nameComparison = a.cityName.toLowerCase().compareTo(
        b.cityName.toLowerCase(),
      );

      if (nameComparison != 0) {
        return nameComparison;
      }

      final countryComparison = a.countryCode.compareTo(b.countryCode);

      if (countryComparison != 0) {
        return countryComparison;
      }

      return a.cityId.compareTo(b.cityId);
    });

    return List.unmodifiable(cities);
  }

  List<CityVisit> visitsForCity(int cityId) {
    return List.unmodifiable(visits.where((visit) => visit.cityId == cityId));
  }
}
