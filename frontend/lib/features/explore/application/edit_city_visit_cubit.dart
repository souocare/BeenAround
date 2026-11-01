import 'package:beenaround/features/explore/domain/visit_date_changes_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../../geography/domain/country_visit_date_expansion.dart';
import 'edit_city_visit_state.dart';
import 'pending_city_visit_update.dart';

class EditCityVisitCubit extends Cubit<EditCityVisitState> {
  EditCityVisitCubit({required this._repository})
    : super(const EditCityVisitState());

  final CityVisitsRepository _repository;

  Future<bool> submit({
    required String visitId,
    required Map<String, dynamic> changes,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    if (isClosed ||
        state.isSubmitting ||
        state.phase == EditCityVisitPhase.success) {
      return false;
    }

    final normalizedVisitId = visitId.trim();

    if (normalizedVisitId.isEmpty) {
      emit(
        const EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: 'Invalid visit.',
        ),
      );
      return false;
    }

    if (changes.isEmpty) {
      emit(
        const EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: 'No changes to save.',
        ),
      );
      return false;
    }

    final dateError = VisitDateChangesValidator.validate(changes);

    if (dateError != null) {
      emit(
        EditCityVisitState(
          phase: EditCityVisitPhase.failure,
          errorMessage: dateError,
        ),
      );
      return false;
    }

    // The confirmation must refer to the exact request that originally
    // produced the expansion proposal.
    if (countryDateExpansion != null) {
      final pending = state.pendingUpdate;

      if (state.phase != EditCityVisitPhase.expansionRequired ||
          pending == null ||
          !identical(pending.expansion, countryDateExpansion) ||
          !pending.matches(visitId: normalizedVisitId, changes: changes)) {
        emit(
          const EditCityVisitState(
            phase: EditCityVisitPhase.failure,
            errorMessage: 'The country visit confirmation is no longer valid.',
          ),
        );
        return false;
      }
    }

    // Preserve the caller's input and avoid mutating the original map.
    final requestChanges = Map<String, dynamic>.of(changes);

    if (countryDateExpansion != null) {
      requestChanges['country_date_expansion'] = countryDateExpansion;
    }

    emit(const EditCityVisitState(phase: EditCityVisitPhase.submitting));

    try {
      await _repository.updateCityVisit(
        visitId: normalizedVisitId,
        changes: requestChanges,
      );

      if (isClosed) return false;

      emit(const EditCityVisitState(phase: EditCityVisitPhase.success));

      return true;
    } on CountryVisitDateExpansionRequired catch (error) {
      if (isClosed) return false;

      // If the request explicitly targets a country visit, the proposal
      // must refer to the same visit.
      if (changes.containsKey('country_visit_id') &&
          changes['country_visit_id'] != error.expansion.countryVisitId) {
        emit(
          const EditCityVisitState(
            phase: EditCityVisitPhase.failure,
            errorMessage: 'The country visit proposal does not match.',
          ),
        );
        return false;
      }

      emit(
        EditCityVisitState(
          phase: EditCityVisitPhase.expansionRequired,
          pendingUpdate: PendingCityVisitUpdate(
            visitId: normalizedVisitId,
            changes: changes,
            expansion: error.expansion,
          ),
        ),
      );

      return false;
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
    if (isClosed || state.phase != EditCityVisitPhase.failure) {
      return;
    }

    emit(const EditCityVisitState());
  }

  void dismissExpansion() {
    if (isClosed || state.phase != EditCityVisitPhase.expansionRequired) {
      return;
    }

    emit(const EditCityVisitState());
  }
}
