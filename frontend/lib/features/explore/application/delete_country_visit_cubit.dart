import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/countries_repository.dart';
import 'delete_country_visit_state.dart';

class DeleteCountryVisitCubit extends Cubit<DeleteCountryVisitState> {
  DeleteCountryVisitCubit({required CountriesRepository repository})
    : _repository = repository,
      super(const DeleteCountryVisitState());

  final CountriesRepository _repository;

  Future<bool> delete({required String visitId}) async {
    if (isClosed ||
        state.isDeleting ||
        state.phase == DeleteCountryVisitPhase.success) {
      return false;
    }

    final normalizedId = visitId.trim();

    if (normalizedId.isEmpty) {
      emit(
        const DeleteCountryVisitState(
          phase: DeleteCountryVisitPhase.failure,
          errorMessage: 'Invalid visit.',
        ),
      );

      return false;
    }

    emit(
      const DeleteCountryVisitState(phase: DeleteCountryVisitPhase.deleting),
    );

    try {
      await _repository.deleteCountryVisit(visitId: normalizedId);

      if (isClosed) return false;

      emit(
        const DeleteCountryVisitState(phase: DeleteCountryVisitPhase.success),
      );

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        DeleteCountryVisitState(
          phase: DeleteCountryVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const DeleteCountryVisitState(
          phase: DeleteCountryVisitPhase.failure,
          errorMessage: 'Unable to delete your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (isClosed || state.phase != DeleteCountryVisitPhase.failure) {
      return;
    }

    emit(const DeleteCountryVisitState());
  }
}
