import 'package:flutter_bloc/flutter_bloc.dart';

import '../../geography/domain/city_visits_repository.dart';
import 'visited_cities_state.dart';

class VisitedCitiesCubit extends Cubit<VisitedCitiesState> {
  VisitedCitiesCubit({required CityVisitsRepository repository})
    : _repository = repository,
      super(const VisitedCitiesState());

  final CityVisitsRepository _repository;

  Future<void> load() async {
    if (isClosed) return;

    emit(
      VisitedCitiesState(
        phase: VisitedCitiesPhase.loading,
        visits: state.visits,
      ),
    );

    try {
      final visits = await _repository.getCityVisits();

      if (isClosed) return;

      emit(
        VisitedCitiesState(
          phase: VisitedCitiesPhase.ready,
          visits: List.unmodifiable(visits),
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        VisitedCitiesState(
          phase: VisitedCitiesPhase.failure,
          visits: state.visits,
          errorMessage: 'Unable to load visited cities.',
        ),
      );
    }
  }
}
