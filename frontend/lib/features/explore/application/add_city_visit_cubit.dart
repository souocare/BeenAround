import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../domain/country_visit_date_validator.dart';
import 'add_city_visit_state.dart';

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
  }) async {
    if (state.isSubmitting || state.phase == AddCityVisitPhase.success) {
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

    emit(const AddCityVisitState(phase: AddCityVisitPhase.submitting));

    try {
      await _repository.createCityVisit(
        cityId: cityId,
        startedOn: startedOn,
        endedOn: endedOn,
        startedOnPrecision: startedOnPrecision,
        endedOnPrecision: endedOnPrecision,
      );

      if (isClosed) return false;

      emit(const AddCityVisitState(phase: AddCityVisitPhase.success));

      return true;
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
    if (state.phase != AddCityVisitPhase.failure) return;

    emit(const AddCityVisitState());
  }
}
