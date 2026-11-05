import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/trip_repository.dart';

import 'trips_state.dart';

class TripsCubit extends Cubit<TripsState> {
  TripsCubit({required TripRepository repository})
    : _repository = repository,
      super(const TripsState());

  final TripRepository _repository;

  int _requestGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(TripsState(phase: TripsPhase.loading, trips: state.trips));

    try {
      final trips = await _repository.getTrips();

      if (!_isCurrent(generation)) return;

      emit(
        TripsState(phase: TripsPhase.ready, trips: List.unmodifiable(trips)),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        TripsState(
          phase: TripsPhase.failure,
          trips: state.trips,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        TripsState(
          phase: TripsPhase.failure,
          trips: state.trips,
          errorMessage: 'Unable to load your Trips.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;

    return super.close();
  }
}
