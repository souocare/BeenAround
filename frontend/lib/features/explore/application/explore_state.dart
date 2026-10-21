import '../domain/country.dart';
import '../domain/country_visit.dart';

enum ExplorePhase { initial, loading, ready, failure }

class ExploreState {
  const ExploreState({
    this.phase = ExplorePhase.initial,
    this.countries = const [],
    this.visits = const [],
    this.errorMessage,
  });

  final ExplorePhase phase;
  final List<Country> countries;
  final List<CountryVisit> visits;
  final String? errorMessage;

  bool get hasData => phase == ExplorePhase.ready;

  Set<String> get visitedCountryCodes =>
      visits.map((visit) => visit.countryCode).toSet();

  int get visitedCountryCount => visitedCountryCodes.length;

  int get totalVisits => visits.length;

  int get totalCountries => countries.length;

  int get unvisitedCountryCount => countries
      .where((country) => !visitedCountryCodes.contains(country.code))
      .length;

  bool isCountryVisited(String countryCode) =>
      visitedCountryCodes.contains(countryCode);

  List<CountryVisit> visitsForCountry(String countryCode) => visits
      .where((visit) => visit.countryCode == countryCode)
      .toList(growable: false);
}
