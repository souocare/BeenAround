import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/countries_repository.dart';
import 'add_country_visit_state.dart';

class AddCountryVisitCubit extends Cubit<AddCountryVisitState> {
  AddCountryVisitCubit({required CountriesRepository repository})
    : _repository = repository,
      super(const AddCountryVisitState());

  final CountriesRepository _repository;

  Future<bool> submit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    if (state.isSubmitting || state.phase == AddCountryVisitPhase.success) {
      return false;
    }

    final normalizedCode = countryCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      emit(
        const AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: 'Please select a country.',
        ),
      );

      return false;
    }

    if (endedOn != null && startedOn == null) {
      emit(
        const AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: 'An end date requires a start date.',
        ),
      );

      return false;
    }

    if (startedOn != null &&
        endedOn != null &&
        _dateOnly(endedOn).isBefore(_dateOnly(startedOn))) {
      emit(
        const AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: 'End date cannot be earlier than start date.',
        ),
      );

      return false;
    }

    emit(const AddCountryVisitState(phase: AddCountryVisitPhase.submitting));

    try {
      await _repository.createCountryVisit(
        countryCode: normalizedCode,
        startedOn: startedOn,
        endedOn: endedOn,
      );

      if (isClosed) return false;

      emit(const AddCountryVisitState(phase: AddCountryVisitPhase.success));

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: error.message,
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        const AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: 'Unable to save your visit. Please try again.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (state.phase != AddCountryVisitPhase.failure) return;

    emit(const AddCountryVisitState());
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
