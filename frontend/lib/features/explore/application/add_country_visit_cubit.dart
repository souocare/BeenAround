import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../../trips/domain/trip_association_repository.dart';

import '../data/countries_repository.dart';
import '../domain/country_visit_date_validator.dart';

import 'add_country_visit_state.dart';

/// Creates independent country visits and optionally associates them
/// with an explicitly selected Trip.
///
/// A successful visit creation is never repeated merely because
/// the subsequent Trip association failed.
class AddCountryVisitCubit extends Cubit<AddCountryVisitState> {
  AddCountryVisitCubit({
    required CountriesRepository repository,
    TripAssociationRepository? tripAssociationRepository,
  }) : _repository = repository,
       _tripAssociationRepository = tripAssociationRepository,
       super(const AddCountryVisitState());

  final CountriesRepository _repository;

  final TripAssociationRepository? _tripAssociationRepository;

  /// Create an independent country visit and optionally associate it
  /// with an existing Trip.
  ///
  /// Returns true only when the requested workflow succeeds completely.
  ///
  /// When the visit is created but its association fails, the state
  /// retains both identifiers for retryAssociation().
  Future<bool> submit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
    String? tripId,
  }) async {
    if (isClosed ||
        state.isSubmitting ||
        state.phase == AddCountryVisitPhase.success ||
        state.hasCreatedVisit) {
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

    final dateError = CountryVisitDateValidator.validate(
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
    );

    if (dateError != null) {
      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.failure,
          errorMessage: dateError,
        ),
      );

      return false;
    }

    final normalizedTripId = tripId?.trim();

    if (normalizedTripId != null) {
      if (normalizedTripId.isEmpty) {
        emit(
          const AddCountryVisitState(
            phase: AddCountryVisitPhase.failure,
            errorMessage: 'Please select a valid Trip.',
          ),
        );

        return false;
      }

      if (_tripAssociationRepository == null) {
        throw StateError(
          'TripAssociationRepository is required when a Trip is selected.',
        );
      }
    }

    // Date validation guarantees both dates are available.
    final validStartedOn = startedOn!;
    final validEndedOn = endedOn!;

    emit(const AddCountryVisitState(phase: AddCountryVisitPhase.submitting));

    // ---------------------------------------------------------
    // Step 1: Create the independent CountryVisit.
    // ---------------------------------------------------------

    late final String createdVisitId;

    try {
      final visit = await _repository.createCountryVisit(
        countryCode: normalizedCode,
        startedOn: validStartedOn,
        endedOn: validEndedOn,
        startedOnPrecision: startedOnPrecision ?? VisitDatePrecision.day,
        endedOnPrecision: endedOnPrecision ?? VisitDatePrecision.day,
      );

      if (isClosed) return false;

      createdVisitId = visit.id;
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

    // ---------------------------------------------------------
    // Step 2: No Trip selected — registration is complete.
    // ---------------------------------------------------------

    if (normalizedTripId == null) {
      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.success,
          createdVisitId: createdVisitId,
        ),
      );

      return true;
    }

    // ---------------------------------------------------------
    // Step 3: Associate the existing visit with the selected Trip.
    // ---------------------------------------------------------

    emit(
      AddCountryVisitState(
        phase: AddCountryVisitPhase.associating,
        createdVisitId: createdVisitId,
        selectedTripId: normalizedTripId,
      ),
    );

    return _associateVisit(visitId: createdVisitId, tripId: normalizedTripId);
  }

  /// Retry only the Trip association after a partial failure.
  ///
  /// Never creates another CountryVisit.
  Future<bool> retryAssociation() async {
    if (isClosed || state.isSubmitting || !state.hasAssociationFailure) {
      return false;
    }

    final visitId = state.createdVisitId;
    final tripId = state.selectedTripId;

    if (visitId == null || tripId == null) {
      return false;
    }

    emit(
      AddCountryVisitState(
        phase: AddCountryVisitPhase.associating,
        createdVisitId: visitId,
        selectedTripId: tripId,
      ),
    );

    return _associateVisit(visitId: visitId, tripId: tripId);
  }

  Future<bool> _associateVisit({
    required String visitId,
    required String tripId,
  }) async {
    try {
      await _tripAssociationRepository!.addCountryVisit(
        tripId: tripId,
        visitId: visitId,
      );

      if (isClosed) return false;

      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.success,
          createdVisitId: visitId,
          selectedTripId: tripId,
        ),
      );

      return true;
    } on ApiException catch (error) {
      if (isClosed) return false;

      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.associationFailure,
          createdVisitId: visitId,
          selectedTripId: tripId,
          errorMessage:
              'Your visit was saved, but we could not add it '
              'to the selected Trip. ${error.message}',
        ),
      );

      return false;
    } catch (_) {
      if (isClosed) return false;

      emit(
        AddCountryVisitState(
          phase: AddCountryVisitPhase.associationFailure,
          createdVisitId: visitId,
          selectedTripId: tripId,
          errorMessage:
              'Your visit was saved, but we could not add it '
              'to the selected Trip.',
        ),
      );

      return false;
    }
  }

  void clearError() {
    if (isClosed) return;

    // An association failure must retain the created visit ID.
    //
    // Resetting to idle would allow the next submit() to create
    // a duplicate country visit.
    if (state.hasAssociationFailure) {
      return;
    }

    if (state.phase != AddCountryVisitPhase.failure) {
      return;
    }

    emit(const AddCountryVisitState());
  }
}
