import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../../geography/domain/country_visit_date_expansion.dart';
import '../../geography/domain/new_country_visit_input.dart';
import '../domain/country_visit_date_validator.dart';
import 'add_city_visit_state.dart';
import 'pending_city_visit_creation.dart';

class AddCityVisitCubit extends Cubit<AddCityVisitState> {
  AddCityVisitCubit({required CityVisitsRepository repository})
    : _repository = repository,
      super(const AddCityVisitState());

  final CityVisitsRepository _repository;

  Future<bool> submit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    if (isClosed ||
        state.isSubmitting ||
        state.phase == AddCityVisitPhase.success) {
      return false;
    }

    if (cityId <= 0) {
      emit(
        const AddCityVisitState(
          phase: AddCityVisitPhase.failure,
          errorMessage: 'Please select a city.',
        ),
      );
      return false;
    }

    final dateError = CountryVisitDateValidator.validate(
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
    );

    if (dateError != null) {
      emit(
        AddCityVisitState(
          phase: AddCityVisitPhase.failure,
          errorMessage: dateError,
        ),
      );
      return false;
    }

    final validStartedOn = startedOn!;
    final validEndedOn = endedOn!;
    final validStartPrecision = startedOnPrecision ?? VisitDatePrecision.day;
    final validEndPrecision = endedOnPrecision ?? VisitDatePrecision.day;

    // A confirmation must match the exact request that generated it.
    if (countryDateExpansion != null) {
      final pending = state.pendingCreation;

      if (state.phase != AddCityVisitPhase.expansionRequired ||
          pending == null ||
          !identical(pending.expansion, countryDateExpansion) ||
          countryVisitId == null ||
          newCountryVisit != null ||
          !pending.matches(
            cityId: cityId,
            startedOn: validStartedOn,
            endedOn: validEndedOn,
            startedOnPrecision: validStartPrecision,
            endedOnPrecision: validEndPrecision,
            countryVisitId: countryVisitId,
          )) {
        emit(
          const AddCityVisitState(
            phase: AddCityVisitPhase.failure,
            errorMessage: 'The country visit confirmation is no longer valid.',
          ),
        );
        return false;
      }
    }

    emit(const AddCityVisitState(phase: AddCityVisitPhase.submitting));

    try {
      await _repository.createCityVisit(
        cityId: cityId,
        startedOn: validStartedOn,
        endedOn: validEndedOn,
        startedOnPrecision: validStartPrecision,
        endedOnPrecision: validEndPrecision,
        countryVisitId: countryVisitId,
        newCountryVisit: newCountryVisit,
        countryDateExpansion: countryDateExpansion,
      );

      if (isClosed) return false;

      emit(const AddCityVisitState(phase: AddCityVisitPhase.success));

      return true;
    } on CountryVisitDateExpansionRequired catch (error) {
      if (isClosed) return false;

      if (countryVisitId == null || newCountryVisit != null) {
        emit(
          const AddCityVisitState(
            phase: AddCityVisitPhase.failure,
            errorMessage: 'Invalid country visit expansion proposal.',
          ),
        );
        return false;
      }

      if (error.expansion.countryVisitId != countryVisitId) {
        emit(
          const AddCityVisitState(
            phase: AddCityVisitPhase.failure,
            errorMessage: 'The country visit proposal does not match.',
          ),
        );
        return false;
      }

      emit(
        AddCityVisitState(
          phase: AddCityVisitPhase.expansionRequired,
          pendingCreation: PendingCityVisitCreation(
            cityId: cityId,
            startedOn: validStartedOn,
            endedOn: validEndedOn,
            startedOnPrecision: validStartPrecision,
            endedOnPrecision: validEndPrecision,
            countryVisitId: countryVisitId,
            expansion: error.expansion,
          ),
        ),
      );

      return false;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        AddCityVisitState(
          phase: AddCityVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const AddCityVisitState(
          phase: AddCityVisitPhase.failure,
          errorMessage: 'Unable to save your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (isClosed || state.phase != AddCityVisitPhase.failure) return;

    emit(const AddCityVisitState());
  }

  void dismissExpansion() {
    if (isClosed || state.phase != AddCityVisitPhase.expansionRequired) {
      return;
    }

    emit(const AddCityVisitState());
  }
}
