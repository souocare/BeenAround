import '../../explore/domain/visited_city.dart';
import '../../trips/domain/trip.dart';

enum MapCountryRelatedPhase { initial, loading, ready, failure }

/// Read-only information associated with a selected country.
///
/// City visits and Trips remain independent domain records.
class MapCountryRelatedState {
  const MapCountryRelatedState({
    this.phase = MapCountryRelatedPhase.initial,
    this.countryCode,
    this.cities = const [],
    this.trips = const [],
    this.errorMessage,
  });

  final MapCountryRelatedPhase phase;
  final String? countryCode;

  final List<VisitedCity> cities;
  final List<Trip> trips;

  final String? errorMessage;

  bool get isLoading => phase == MapCountryRelatedPhase.loading;

  bool get hasData => phase == MapCountryRelatedPhase.ready;

  int get cityCount => cities.length;

  int get tripCount => trips.length;
}
