import 'package:flutter_bloc/flutter_bloc.dart';

import '../../explore/application/visited_cities_state.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../../trips/domain/trip_repository.dart';

import 'map_country_related_state.dart';

/// Loads cities and explicitly associated Trips for a selected country.
///
/// This Cubit never creates visits, Trips or associations.
class MapCountryRelatedCubit extends Cubit<MapCountryRelatedState> {
  MapCountryRelatedCubit({
    required CityVisitsRepository cityVisitsRepository,
    required TripRepository tripRepository,
  }) : _cityVisitsRepository = cityVisitsRepository,
       _tripRepository = tripRepository,
       super(const MapCountryRelatedState());

  final CityVisitsRepository _cityVisitsRepository;
  final TripRepository _tripRepository;

  int _generation = 0;

  Future<void> load(String countryCode) async {
    final normalizedCode = countryCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      clear();
      return;
    }

    // Do not reload data for the same country if it is already ready.
    if (state.countryCode == normalizedCode &&
        state.phase == MapCountryRelatedPhase.ready) {
      return;
    }

    final generation = ++_generation;

    emit(
      MapCountryRelatedState(
        phase: MapCountryRelatedPhase.loading,
        countryCode: normalizedCode,
      ),
    );

    try {
      final cityVisits = await _cityVisitsRepository.getCityVisits();

      if (!_isCurrent(generation)) return;

      final visitedCities = VisitedCitiesState(
        phase: VisitedCitiesPhase.ready,
        visits: cityVisits,
      ).visitedCities;

      final countryCities = visitedCities
          .where((city) => city.countryCode == normalizedCode)
          .toList(growable: false);

      final trips = await _tripRepository.getTripsForCountry(
        countryCode: normalizedCode,
      );

      if (!_isCurrent(generation)) return;

      emit(
        MapCountryRelatedState(
          phase: MapCountryRelatedPhase.ready,
          countryCode: normalizedCode,
          cities: List.unmodifiable(countryCities),
          trips: List.unmodifiable(trips),
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        MapCountryRelatedState(
          phase: MapCountryRelatedPhase.failure,
          countryCode: normalizedCode,
          errorMessage: 'Unable to load country details.',
        ),
      );
    }
  }

  void clear() {
    ++_generation;

    emit(const MapCountryRelatedState());
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _generation;
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
