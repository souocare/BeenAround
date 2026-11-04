import 'package:flutter_bloc/flutter_bloc.dart';

import '../../geography/domain/city.dart';
import '../../geography/domain/city_repository.dart';
import '../../geography/domain/city_id_resolution.dart';

import '../../residences/application/residences_state.dart';
import '../../wishlist/application/wishlist_state.dart';

import 'explore_city_aggregation.dart';
import 'explore_cities_state.dart';
import 'visited_cities_state.dart';

/// Coordinates catalog resolution and aggregation of city travel statuses.
///
/// Source records remain owned by their respective Cubits.
class ExploreCitiesCubit extends Cubit<ExploreCitiesState> {
  ExploreCitiesCubit({required CityRepository cityRepository})
    : _cityRepository = cityRepository,
      super(const ExploreCitiesState());

  final CityRepository _cityRepository;

  int _requestGeneration = 0;

  /// Builds the aggregated city collection from loaded source states.
  ///
  /// All three sources must be ready. Incomplete source states must not
  /// be interpreted as an empty or definitive travel history.
  ///
  /// Each catalog request is limited to 200 IDs.
  Future<void> load({
    required VisitedCitiesState visitedCities,
    required ResidencesState residences,
    required WishlistState wishlist,
  }) async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    if (visitedCities.phase != VisitedCitiesPhase.ready ||
        residences.phase != ResidencesPhase.ready ||
        wishlist.phase != WishlistPhase.ready) {
      // Invalidate older requests without publishing incomplete data.
      //
      // Existing results remain available but must not be treated
      // as a freshly computed snapshot.
      emit(
        ExploreCitiesState(
          phase: ExploreCitiesPhase.initial,
          cities: state.cities,
        ),
      );

      return;
    }

    emit(
      ExploreCitiesState(
        phase: ExploreCitiesPhase.loading,
        cities: state.cities,
      ),
    );

    try {
      final cityIds = collectExploreCityIds(
        visitedCities: visitedCities,
        residences: residences,
        wishlist: wishlist,
      );

      final resolvedCities = <City>[];

      for (
        var offset = 0;
        offset < cityIds.length;
        offset += maxCityResolutionIds
      ) {
        if (!_isCurrent(generation)) return;

        final end = offset + maxCityResolutionIds < cityIds.length
            ? offset + maxCityResolutionIds
            : cityIds.length;

        final batch = cityIds.sublist(offset, end);

        final cities = await _cityRepository.resolveByIds(cityIds: batch);

        if (!_isCurrent(generation)) return;

        resolvedCities.addAll(cities);
      }

      final aggregated = aggregateExploreCities(
        cities: resolvedCities,
        visitedCities: visitedCities,
        residences: residences,
        wishlist: wishlist,
      );

      if (!_isCurrent(generation)) return;

      emit(
        ExploreCitiesState(phase: ExploreCitiesPhase.ready, cities: aggregated),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        ExploreCitiesState(
          phase: ExploreCitiesPhase.failure,
          cities: state.cities,
          errorMessage: 'Unable to load Explore cities.',
        ),
      );
    }
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;
    return super.close();
  }
}
