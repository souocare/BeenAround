import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/residence_repository.dart';
import 'residences_state.dart';

class ResidencesCubit extends Cubit<ResidencesState> {
  ResidencesCubit({required ResidenceRepository repository})
    : _repository = repository,
      super(const ResidencesState());

  final ResidenceRepository _repository;

  int _requestGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(
      ResidencesState(
        phase: ResidencesPhase.loading,
        residences: state.residences,
      ),
    );

    try {
      final residences = await _repository.getResidences();

      if (!_isCurrent(generation)) return;

      emit(
        ResidencesState(
          phase: ResidencesPhase.ready,
          residences: List.unmodifiable(residences),
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        ResidencesState(
          phase: ResidencesPhase.failure,
          residences: state.residences,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        ResidencesState(
          phase: ResidencesPhase.failure,
          residences: state.residences,
          errorMessage: 'Unable to load your residence history.',
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
