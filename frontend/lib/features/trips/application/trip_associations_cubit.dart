import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_visit.dart';

import '../domain/trip_association_repository.dart';
import 'trip_associations_state.dart';

/// Coordinates the independent visits associated with one Trip.
class TripAssociationsCubit extends Cubit<TripAssociationsState> {
  TripAssociationsCubit({
    required TripAssociationRepository repository,
    required this.tripId,
  }) : _repository = repository,
       super(const TripAssociationsState());

  final TripAssociationRepository _repository;

  final String tripId;

  /// Invalidates responses from obsolete requests.
  int _requestGeneration = 0;

  // ---------------------------------------------------------
  // Loading
  // ---------------------------------------------------------

  Future<void> load() => _reload();

  Future<void> refresh() => _reload();

  Future<void> _reload({bool duringMutation = false}) async {
    if (isClosed) return;

    // External refreshes must not interfere with a mutation.
    if (state.isMutating && !duringMutation) {
      return;
    }

    final generation = ++_requestGeneration;

    emit(state.copyWith(isLoading: true, loadError: null));

    try {
      // Start both requests without waiting for the first
      // before starting the second.
      final results = await Future.wait<Object>([
        _repository.getCountryVisits(tripId: tripId),
        _repository.getCityVisits(tripId: tripId),
      ]);

      if (!_isCurrent(generation)) return;

      final countries = results[0] as List<CountryVisit>;
      final cities = results[1] as List<CityVisit>;

      emit(
        state.copyWith(
          countryVisits: List.unmodifiable(countries),
          cityVisits: List.unmodifiable(cities),
          hasLoaded: true,
          isLoading: false,
          loadError: null,
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(state.copyWith(isLoading: false, loadError: error.message));
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        state.copyWith(
          isLoading: false,
          loadError: 'Unable to load Trip visits.',
        ),
      );
    }
  }

  // ---------------------------------------------------------
  // Country associations
  // ---------------------------------------------------------

  Future<void> addCountryVisit({required String visitId}) {
    return _mutate(
      () => _repository.addCountryVisit(tripId: tripId, visitId: visitId),
    );
  }

  /// Associates multiple existing country visits with this Trip.
  ///
  /// Associations are performed sequentially to avoid concurrent mutations.
  /// Successful associations are preserved if a later request fails.
  Future<void> addCountryVisits({required List<String> visitIds}) {
    return _addVisitsBatch(
      visitIds: visitIds,
      addVisit: (visitId) =>
          _repository.addCountryVisit(tripId: tripId, visitId: visitId),
    );
  }

  /// Associates multiple existing city visits with this Trip.
  Future<void> addCityVisits({required List<String> visitIds}) {
    return _addVisitsBatch(
      visitIds: visitIds,
      addVisit: (visitId) =>
          _repository.addCityVisit(tripId: tripId, visitId: visitId),
    );
  }

  Future<void> removeCountryVisit({required String visitId}) {
    return _mutate(
      () => _repository.removeCountryVisit(tripId: tripId, visitId: visitId),
    );
  }

  // ---------------------------------------------------------
  // City associations
  // ---------------------------------------------------------

  Future<void> addCityVisit({required String visitId}) {
    return _mutate(
      () => _repository.addCityVisit(tripId: tripId, visitId: visitId),
    );
  }

  Future<void> removeCityVisit({required String visitId}) {
    return _mutate(
      () => _repository.removeCityVisit(tripId: tripId, visitId: visitId),
    );
  }

  // ---------------------------------------------------------
  // Shared mutation logic
  // ---------------------------------------------------------

  Future<void> _addVisitsBatch({
    required List<String> visitIds,
    required Future<void> Function(String visitId) addVisit,
  }) async {
    if (isClosed || state.isMutating) {
      return;
    }

    // Preserve selection order and avoid duplicate requests.
    final uniqueVisitIds = visitIds.toSet().toList(growable: false);

    if (uniqueVisitIds.isEmpty) {
      return;
    }

    // Invalidate any older loading request.
    ++_requestGeneration;

    emit(
      state.copyWith(
        isMutating: true,
        isLoading: false,
        loadError: null,
        mutationError: null,
      ),
    );

    var completed = 0;
    String? failureMessage;

    for (final visitId in uniqueVisitIds) {
      if (isClosed) return;

      try {
        await addVisit(visitId);
        completed++;
      } on ApiException catch (error) {
        failureMessage = error.message;
        break;
      } catch (_) {
        failureMessage = 'Unable to add this visit.';
        break;
      }
    }

    if (isClosed) return;

    // Reconcile with the backend even after a partial failure.
    //
    // Some associations may already have succeeded, so keeping
    // the previous state would present incorrect information.
    await _reload(duringMutation: true);

    if (isClosed) return;

    final mutationError = failureMessage == null
        ? null
        : 'Added $completed of ${uniqueVisitIds.length} visits. '
              '$failureMessage';

    emit(state.copyWith(isMutating: false, mutationError: mutationError));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (isClosed || state.isMutating) {
      return;
    }

    // Invalidate any loading request already in progress.
    ++_requestGeneration;

    emit(
      state.copyWith(
        isMutating: true,
        isLoading: false,
        loadError: null,
        mutationError: null,
      ),
    );

    try {
      await action();

      if (isClosed) return;

      // Reconcile the state with the backend.
      await _reload(duringMutation: true);
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(state.copyWith(mutationError: error.message));
    } catch (_) {
      if (isClosed) return;

      emit(state.copyWith(mutationError: 'Unable to update Trip visits.'));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isMutating: false));
      }
    }
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;
    return super.close();
  }
}
