import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../geography/domain/city_visits_repository.dart';
import 'delete_city_visit_state.dart';

class DeleteCityVisitCubit extends Cubit<DeleteCityVisitState> {
  DeleteCityVisitCubit({required CityVisitsRepository repository})
    : _repository = repository,
      super(const DeleteCityVisitState());

  final CityVisitsRepository _repository;

  Future<bool> delete({required String visitId}) async {
    if (isClosed ||
        state.isDeleting ||
        state.phase == DeleteCityVisitPhase.success) {
      return false;
    }

    final normalizedId = visitId.trim();

    if (normalizedId.isEmpty) {
      emit(
        const DeleteCityVisitState(
          phase: DeleteCityVisitPhase.failure,
          errorMessage: 'Invalid visit.',
        ),
      );

      return false;
    }

    emit(const DeleteCityVisitState(phase: DeleteCityVisitPhase.deleting));

    try {
      await _repository.deleteCityVisit(visitId: normalizedId);

      if (isClosed) return false;

      emit(const DeleteCityVisitState(phase: DeleteCityVisitPhase.success));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        DeleteCityVisitState(
          phase: DeleteCityVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const DeleteCityVisitState(
          phase: DeleteCityVisitPhase.failure,
          errorMessage: 'Unable to delete your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (isClosed || state.phase != DeleteCityVisitPhase.failure) {
      return;
    }

    emit(const DeleteCityVisitState());
  }
}
