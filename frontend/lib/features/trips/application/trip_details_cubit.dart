import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/trip_repository.dart';
import 'trip_details_state.dart';

class TripDetailsCubit extends Cubit<TripDetailsState> {
  TripDetailsCubit({required TripRepository repository, required this.tripId})
    : _repository = repository,
      super(const TripDetailsState());

  final TripRepository _repository;
  final String tripId;

  int _requestGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(TripDetailsState(phase: TripDetailsPhase.loading, trip: state.trip));

    try {
      final trip = await _repository.getTrip(tripId: tripId);

      if (!_isCurrent(generation)) return;

      emit(TripDetailsState(phase: TripDetailsPhase.ready, trip: trip));
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        TripDetailsState(
          phase: TripDetailsPhase.failure,
          trip: state.trip,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        TripDetailsState(
          phase: TripDetailsPhase.failure,
          trip: state.trip,
          errorMessage: 'Unable to load this Trip.',
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
