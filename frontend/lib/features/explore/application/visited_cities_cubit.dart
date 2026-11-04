import 'package:flutter_bloc/flutter_bloc.dart';

import '../../geography/domain/city_visits_repository.dart';
import 'visited_cities_state.dart';

class VisitedCitiesCubit extends Cubit<VisitedCitiesState> {
  VisitedCitiesCubit({required CityVisitsRepository repository})
    : _repository = repository,
      super(const VisitedCitiesState());

  final CityVisitsRepository _repository;

  int _requestGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(
      VisitedCitiesState(
        phase: VisitedCitiesPhase.loading,
        visits: state.visits,
      ),
    );

    try {
      final visits = await _repository.getCityVisits();

      if (!_isCurrent(generation)) return;

      emit(
        VisitedCitiesState(
          phase: VisitedCitiesPhase.ready,
          visits: List.unmodifiable(visits),
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        VisitedCitiesState(
          phase: VisitedCitiesPhase.failure,
          visits: state.visits,
          errorMessage: 'Unable to load visited cities.',
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
