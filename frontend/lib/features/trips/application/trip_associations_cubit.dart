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
