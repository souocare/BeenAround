import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/flight.dart';
import '../domain/flight_repository.dart';

import 'flight_catalog_resolver.dart';
import 'flights_state.dart';

/// Manages the authenticated user's paginated flight history.
class FlightsCubit extends Cubit<FlightsState> {
  FlightsCubit({
    required FlightRepository repository,
    required FlightCatalogResolver catalogResolver,
    this.pageSize = 20,
  }) : assert(pageSize > 0 && pageSize <= 100),
       _repository = repository,
       _catalogResolver = catalogResolver,
       super(FlightsState());

  final FlightRepository _repository;
  final FlightCatalogResolver _catalogResolver;

  final int pageSize;

  int _requestGeneration = 0;

  /// Server-side offset for the next page.
  ///
  /// This is deliberately separate from flights.length because the
  /// API may return duplicate records between paginated requests.
  int _nextOffset = 0;

  bool _loadingMore = false;

  /// Load the first page.
  ///
  /// Previous data remains visible while refreshing.
  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    // Invalidate any older pagination request.
    _loadingMore = false;

    emit(
      FlightsState(
        phase: FlightsPhase.loading,
        flights: state.flights,
        airports: state.airports,
        airlines: state.airlines,
        total: state.total,
      ),
    );

    try {
      final page = await _repository.getFlights(limit: pageSize, offset: 0);

      if (!_isCurrent(generation)) return;

      final catalog = await _catalogResolver.resolve(page.items);

      if (!_isCurrent(generation)) return;

      _nextOffset = page.offset + page.items.length;

      emit(
        FlightsState(
          phase: FlightsPhase.ready,
          flights: page.items,
          airports: catalog.airports,
          airlines: catalog.airlines,
          total: page.total,
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      _emitLoadFailure(error.message);
    } catch (_) {
      if (!_isCurrent(generation)) return;

      _emitLoadFailure('Unable to load your flights.');
    }
  }

  /// Refresh the first page from the backend.
  Future<void> refresh() => load();

  /// Fetch another page without discarding the existing history.
  Future<void> loadMore() async {
    if (isClosed || _loadingMore) return;

    if (state.phase != FlightsPhase.ready || !state.hasMore) {
      return;
    }

    final generation = _requestGeneration;
    final current = state;
    final offset = _nextOffset;

    _loadingMore = true;

    emit(
      FlightsState(
        phase: FlightsPhase.ready,
        flights: current.flights,
        airports: current.airports,
        airlines: current.airlines,
        total: current.total,
        isLoadingMore: true,
      ),
    );

    try {
      final page = await _repository.getFlights(
        limit: pageSize,
        offset: offset,
      );

      if (!_isCurrent(generation)) return;

      final existingIds = current.flights.map((flight) => flight.id).toSet();

      final newFlights = [
        for (final flight in page.items)
          if (existingIds.add(flight.id)) flight,
      ];

      final catalog = await _catalogResolver.resolve(newFlights);

      if (!_isCurrent(generation)) return;

      _nextOffset = page.offset + page.items.length;

      final combinedFlights = [...current.flights, ...newFlights];

      // The backend must not report additional pages while returning
      // an empty page. Avoid an endless pagination loop.
      final reportedTotal = page.items.isEmpty
          ? combinedFlights.length
          : page.total;

      emit(
        FlightsState(
          phase: FlightsPhase.ready,
          flights: combinedFlights,
          airports: {...current.airports, ...catalog.airports},
          airlines: {...current.airlines, ...catalog.airlines},
          total: reportedTotal,
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      _emitPaginationFailure(current, error.message);
    } catch (_) {
      if (!_isCurrent(generation)) return;

      _emitPaginationFailure(current, 'Unable to load more flights.');
    } finally {
      if (_isCurrent(generation)) {
        _loadingMore = false;
      }
    }
  }

  void _emitLoadFailure(String message) {
    emit(
      FlightsState(
        phase: FlightsPhase.failure,
        flights: state.flights,
        airports: state.airports,
        airlines: state.airlines,
        total: state.total,
        errorMessage: message,
      ),
    );
  }

  void _emitPaginationFailure(FlightsState previous, String message) {
    emit(
      FlightsState(
        phase: FlightsPhase.ready,
        flights: previous.flights,
        airports: previous.airports,
        airlines: previous.airlines,
        total: previous.total,
        loadMoreError: message,
      ),
    );
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
