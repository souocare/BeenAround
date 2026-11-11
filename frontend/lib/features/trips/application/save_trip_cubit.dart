import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/trip_input.dart';
import '../domain/trip_repository.dart';

import 'save_trip_state.dart';
import '../domain/trip_association_repository.dart';

/// Coordinates Trip creation and editing.
///
/// Validation belongs to TripInput.
/// Persistence belongs to TripRepository.
/// This Cubit manages the asynchronous operation and its UI state.
class SaveTripCubit extends Cubit<SaveTripState> {
  SaveTripCubit({
    required TripRepository repository,
    TripAssociationRepository? associationRepository,
  }) : _repository = repository,
       _associationRepository = associationRepository,
       super(const SaveTripState());

  final TripRepository _repository;
  final TripAssociationRepository? _associationRepository;

  /// Create a new Trip.
  Future<void> create({required TripInput input}) {
    return _save(input: input);
  }

  /// Creates a Trip and associates explicitly selected existing visits.
  ///
  /// A Trip is created only once. If an association fails after creation,
  /// the persisted Trip and remaining associations are retained for retry.
  Future<void> createWithVisits({
    required TripInput input,
    required List<String> countryVisitIds,
    required List<String> cityVisitIds,
  }) async {
    if (isClosed || state.isSubmitting) {
      return;
    }

    // Once a Trip has been created, it must not be created again.
    if (state.trip != null) {
      return;
    }

    final countries = countryVisitIds.toSet().toList(growable: false);
    final cities = cityVisitIds.toSet().toList(growable: false);

    final associationRepository = _associationRepository;

    if ((countries.isNotEmpty || cities.isNotEmpty) &&
        associationRepository == null) {
      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Trip associations are not available.',
        ),
      );
      return;
    }

    try {
      input.toJson();
    } on ArgumentError catch (error) {
      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: _validationMessage(error),
        ),
      );
      return;
    }

    emit(const SaveTripState(phase: SaveTripPhase.submitting));

    try {
      final trip = await _repository.createTrip(input: input);

      if (isClosed) return;

      // The Trip now exists. Preserve its identity from this point onward.
      emit(
        SaveTripState(
          phase: SaveTripPhase.submitting,
          trip: trip,
          pendingCountryVisitIds: countries,
          pendingCityVisitIds: cities,
        ),
      );

      await _savePendingAssociations(
        trip: trip,
        countryVisitIds: countries,
        cityVisitIds: cities,
      );
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Unable to create your Trip. Please try again.',
        ),
      );
    }
  }

  Future<void> _savePendingAssociations({
    required Trip trip,
    required List<String> countryVisitIds,
    required List<String> cityVisitIds,
  }) async {
    final repository = _associationRepository;

    final pendingCountries = List<String>.of(countryVisitIds);
    final pendingCities = List<String>.of(cityVisitIds);

    // No associations were selected.
    if (pendingCountries.isEmpty && pendingCities.isEmpty) {
      if (!isClosed) {
        emit(SaveTripState(phase: SaveTripPhase.success, trip: trip));
      }
      return;
    }

    if (repository == null) {
      if (!isClosed) {
        emit(
          SaveTripState(
            phase: SaveTripPhase.partialFailure,
            trip: trip,
            pendingCountryVisitIds: pendingCountries,
            pendingCityVisitIds: pendingCities,
            errorMessage: 'Trip associations are not available.',
          ),
        );
      }
      return;
    }

    try {
      for (final visitId in countryVisitIds) {
        if (isClosed) return;

        await repository.addCountryVisit(tripId: trip.id, visitId: visitId);

        if (isClosed) return;

        pendingCountries.remove(visitId);
      }

      for (final visitId in cityVisitIds) {
        if (isClosed) return;

        await repository.addCityVisit(tripId: trip.id, visitId: visitId);

        if (isClosed) return;

        pendingCities.remove(visitId);
      }

      if (isClosed) return;

      emit(SaveTripState(phase: SaveTripPhase.success, trip: trip));
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.partialFailure,
          trip: trip,
          pendingCountryVisitIds: pendingCountries,
          pendingCityVisitIds: pendingCities,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.partialFailure,
          trip: trip,
          pendingCountryVisitIds: pendingCountries,
          pendingCityVisitIds: pendingCities,
          errorMessage:
              'The Trip was created, but some visits could not be associated.',
        ),
      );
    }
  }

  /// Retries pending associations without creating another Trip.
  Future<void> retryPendingAssociations() async {
    if (isClosed || state.isSubmitting || !state.isPartialFailure) {
      return;
    }

    final trip = state.trip;

    if (trip == null) {
      return;
    }

    final pendingCountries = List<String>.of(state.pendingCountryVisitIds);

    final pendingCities = List<String>.of(state.pendingCityVisitIds);

    emit(
      SaveTripState(
        phase: SaveTripPhase.submitting,
        trip: trip,
        pendingCountryVisitIds: pendingCountries,
        pendingCityVisitIds: pendingCities,
      ),
    );

    await _savePendingAssociations(
      trip: trip,
      countryVisitIds: pendingCountries,
      cityVisitIds: pendingCities,
    );
  }

  /// Update an existing Trip.
  Future<void> update({required String tripId, required TripInput input}) {
    return _save(input: input, tripId: tripId);
  }

  Future<void> _save({required TripInput input, String? tripId}) async {
    if (isClosed || state.isSubmitting) {
      return;
    }

    // Validate the complete editable representation before
    // starting the persistence operation.
    //
    // The repository also validates before sending HTTP,
    // providing a second defensive boundary.
    try {
      input.toJson();
    } on ArgumentError catch (error) {
      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: _validationMessage(error),
        ),
      );
      return;
    }

    if (tripId != null && tripId.trim().isEmpty) {
      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Invalid Trip identifier.',
        ),
      );
      return;
    }

    emit(const SaveTripState(phase: SaveTripPhase.submitting));

    try {
      final trip = tripId == null
          ? await _repository.createTrip(input: input)
          : await _repository.updateTrip(tripId: tripId, input: input);

      if (isClosed) return;

      emit(SaveTripState(phase: SaveTripPhase.success, trip: trip));
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: error.message,
        ),
      );
    } on ArgumentError catch (error) {
      if (isClosed) return;

      emit(
        SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: _validationMessage(error),
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        const SaveTripState(
          phase: SaveTripPhase.failure,
          errorMessage: 'Unable to save your Trip. Please try again.',
        ),
      );
    }
  }

  static String _validationMessage(ArgumentError error) {
    final message = error.message;

    if (message is String && message.isNotEmpty) {
      return message;
    }

    return 'Please check the Trip information.';
  }
}
