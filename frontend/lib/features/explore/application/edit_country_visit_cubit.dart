import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/countries_repository.dart';
import '../domain/country_visit_date_validator.dart';
import 'edit_country_visit_state.dart';

class EditCountryVisitCubit extends Cubit<EditCountryVisitState> {
  EditCountryVisitCubit({required CountriesRepository repository})
    : _repository = repository,
      super(const EditCountryVisitState());

  final CountriesRepository _repository;

  Future<bool> submit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    if (state.isSubmitting || state.phase == EditCountryVisitPhase.success) {
      return false;
    }

    if (visitId.trim().isEmpty) {
      emit(
        const EditCountryVisitState(
          phase: EditCountryVisitPhase.failure,
          errorMessage: 'Invalid visit.',
        ),
      );

      return false;
    }

    final dateError = CountryVisitDateValidator.validate(
      startedOn: startedOn,
      endedOn: endedOn,
    );

    if (dateError != null) {
      emit(
        EditCountryVisitState(
          phase: EditCountryVisitPhase.failure,
          errorMessage: dateError,
        ),
      );

      return false;
    }

    emit(const EditCountryVisitState(phase: EditCountryVisitPhase.submitting));

    try {
      await _repository.updateCountryVisit(
        visitId: visitId,
        startedOn: startedOn,
        endedOn: endedOn,
      );

      if (isClosed) return false;

      emit(const EditCountryVisitState(phase: EditCountryVisitPhase.success));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        EditCountryVisitState(
          phase: EditCountryVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const EditCountryVisitState(
          phase: EditCountryVisitPhase.failure,
          errorMessage: 'Unable to update your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (state.phase != EditCountryVisitPhase.failure) return;

    emit(const EditCountryVisitState());
  }
}
