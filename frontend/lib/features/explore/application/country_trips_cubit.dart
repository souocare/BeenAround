import 'package:flutter_bloc/flutter_bloc.dart';

import '../../trips/domain/trip_repository.dart';

import 'country_trips_state.dart';

class CountryTripsCubit extends Cubit<CountryTripsState> {
  CountryTripsCubit({
    required TripRepository repository,
    required this.countryCode,
  }) : _repository = repository,
       super(const CountryTripsState());

  final TripRepository _repository;
  final String countryCode;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;

    emit(
      CountryTripsState(phase: CountryTripsPhase.loading, trips: state.trips),
    );

    try {
      final trips = await _repository.getTripsForCountry(
        countryCode: countryCode,
      );

      if (!_isCurrent(generation)) return;

      emit(
        CountryTripsState(
          phase: CountryTripsPhase.ready,
          trips: List.unmodifiable(trips),
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        const CountryTripsState(
          phase: CountryTripsPhase.failure,
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
