import 'package:flutter_bloc/flutter_bloc.dart';

import '../../trips/domain/trip_repository.dart';
import 'city_trips_state.dart';

class CityTripsCubit extends Cubit<CityTripsState> {
  CityTripsCubit({required TripRepository repository, required this.cityId})
    : _repository = repository,
      super(const CityTripsState());

  final TripRepository _repository;
  final int cityId;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;

    if (isClosed) return;

    emit(CityTripsState(phase: CityTripsPhase.loading, trips: state.trips));

    try {
      final trips = await _repository.getTripsForCity(cityId: cityId);

      if (!_isCurrent(generation)) return;

      emit(
        CityTripsState(
          phase: CityTripsPhase.ready,
          trips: List.unmodifiable(trips),
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        const CityTripsState(
          phase: CityTripsPhase.failure,
          errorMessage: 'Unable to load associated trips.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  bool _isCurrent(int generation) {
    return !isClosed && generation == _generation;
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
