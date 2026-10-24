import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../geography/domain/city_visits_repository.dart';
import 'edit_city_visit_state.dart';

class EditCityVisitCubit extends Cubit<EditCityVisitState> {
  EditCityVisitCubit({required CityVisitsRepository repository})
    : _repository = repository,
      super(const EditCityVisitState());

  final CityVisitsRepository _repository;

  Future<bool> submit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    if (isClosed ||
        state.isSubmitting ||
        state.phase == EditCityVisitPhase.success) {
      return false;
    }

    if (visitId.trim().isEmpty) {
      emit(
        const EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: 'Invalid visit.',
        ),
      );

      return false;
    }

    if (startedOn != null && endedOn != null) {
      final start = DateUtils.dateOnly(startedOn);
      final end = DateUtils.dateOnly(endedOn);

      if (end.isBefore(start)) {
        emit(
          const EditCityVisitState(
            phase: EditCityVisitPhase.failure,
            errorMessage: 'End date cannot be earlier than start date.',
          ),
        );

        return false;
      }
    }

    emit(const EditCityVisitState(phase: EditCityVisitPhase.submitting));

    try {
      await _repository.updateCityVisit(
        visitId: visitId,
        changes: {'started_on': startedOn, 'ended_on': endedOn},
      );

      if (isClosed) return false;

      emit(const EditCityVisitState(phase: EditCityVisitPhase.success));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: 'Unable to update your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (isClosed || state.phase != EditCityVisitPhase.failure) return;

    emit(const EditCityVisitState());
  }
}
