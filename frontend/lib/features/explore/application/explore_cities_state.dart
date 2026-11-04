import 'explore_city_aggregation.dart';

enum ExploreCitiesPhase { initial, loading, ready, failure }

/// Read-only aggregated city data for Explore.
class ExploreCitiesState {
  const ExploreCitiesState({
    this.phase = ExploreCitiesPhase.initial,
    this.cities = const [],
    this.errorMessage,
  });

  final ExploreCitiesPhase phase;

  /// Cities with at least one explicit Been, Lived or Wish status.
  final List<ExploreCityEntry> cities;

  final String? errorMessage;

  bool get isLoading => phase == ExploreCitiesPhase.loading;

  bool get isReady => phase == ExploreCitiesPhase.ready;

  bool get hasError => phase == ExploreCitiesPhase.failure;

  bool get isEmpty => cities.isEmpty;

  int get cityCount => cities.length;

  int get beenCityCount =>
      cities.where((entry) => entry.summary.hasBeen).length;

  int get livedCityCount =>
      cities.where((entry) => entry.summary.hasLived).length;

  int get wishCityCount =>
      cities.where((entry) => entry.summary.isWishlisted).length;
}
