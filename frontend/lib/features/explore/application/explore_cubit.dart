import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/countries_repository.dart';
import 'explore_state.dart';

class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit({required this._repository}) : super(const ExploreState());

  final CountriesRepository _repository;
  CountriesRepository get repository => _repository;

  int _requestGeneration = 0;

  Future<void> load() async {
    final generation = ++_requestGeneration;

    emit(
      ExploreState(
        phase: ExplorePhase.loading,
        countries: state.countries,
        visits: state.visits,
      ),
    );

    try {
      final countries = await _repository.getCountries();

      if (!_isCurrent(generation)) return;

      final visits = await _repository.getCountryVisits();

      if (!_isCurrent(generation)) return;

      emit(
        ExploreState(
          phase: ExplorePhase.ready,
          countries: List.unmodifiable(countries),
          visits: List.unmodifiable(visits),
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        ExploreState(
          phase: ExplorePhase.failure,
          countries: state.countries,
          visits: state.visits,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        ExploreState(
          phase: ExplorePhase.failure,
          countries: state.countries,
          visits: state.visits,
          errorMessage: 'Unable to load your travel history.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  bool _isCurrent(int generation) =>
      !isClosed && generation == _requestGeneration;

  @override
  Future<void> close() {
    ++_requestGeneration;
    return super.close();
  }
}
