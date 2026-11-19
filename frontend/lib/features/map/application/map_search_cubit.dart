import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'map_search_results.dart';
import 'map_search_state.dart';

/// Function responsible for searching geographic catalogs.
typedef MapGeographicSearch = Future<MapSearchResults> Function(String query);

/// Manages geographic search input, debounce and request lifecycle.
///
/// The Cubit does not access geographic repositories directly.
/// Catalog lookups are delegated to the injected search function.
///
/// Search never modifies visits, residences, wishlists or Trips.
class MapSearchCubit extends Cubit<MapSearchState> {
  MapSearchCubit({
    required MapGeographicSearch search,
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) : _search = search,
       _debounceDuration = debounceDuration,
       super(MapSearchState.initial());

  final MapGeographicSearch _search;
  final Duration _debounceDuration;

  Timer? _debounce;

  int _requestGeneration = 0;

  // ---------------------------------------------------------
  // Query changes
  // ---------------------------------------------------------

  /// Updates the search query.
  ///
  /// Each change invalidates previous searches, including
  /// requests that are already in progress.
  void queryChanged(String value) {
    if (isClosed) return;

    _debounce?.cancel();
    _debounce = null;

    final generation = ++_requestGeneration;
    final normalizedQuery = value.trim();

    if (normalizedQuery.isEmpty) {
      emit(MapSearchState.initial());
      return;
    }

    emit(
      MapSearchState(
        query: value,
        phase: MapSearchPhase.waiting,
        results: MapSearchResults(),
      ),
    );

    _debounce = Timer(
      _debounceDuration,
      () => unawaited(
        _executeSearch(query: normalizedQuery, generation: generation),
      ),
    );
  }

  // ---------------------------------------------------------
  // Search execution
  // ---------------------------------------------------------

  Future<void> _executeSearch({
    required String query,
    required int generation,
  }) async {
    if (!_isCurrent(generation)) return;

    emit(
      MapSearchState(
        query: state.query,
        phase: MapSearchPhase.loading,
        results: MapSearchResults(),
      ),
    );

    try {
      final results = await _search(query);

      if (!_isCurrent(generation)) return;

      emit(
        MapSearchState(
          query: state.query,
          phase: results.allFailed
              ? MapSearchPhase.failure
              : MapSearchPhase.ready,
          results: results,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        MapSearchState(
          query: state.query,
          phase: MapSearchPhase.failure,
          results: MapSearchResults(),
        ),
      );
    }
  }

  // ---------------------------------------------------------
  // Retry
  // ---------------------------------------------------------

  /// Retries the current query without waiting for debounce.
  void retry() {
    if (isClosed) return;

    final query = state.query.trim();

    if (query.isEmpty) return;

    _debounce?.cancel();
    _debounce = null;

    final generation = ++_requestGeneration;

    unawaited(_executeSearch(query: query, generation: generation));
  }

  // ---------------------------------------------------------
  // Clear
  // ---------------------------------------------------------

  /// Clears the query and invalidates all pending requests.
  void clear() {
    if (isClosed) return;

    _debounce?.cancel();
    _debounce = null;

    ++_requestGeneration;

    emit(MapSearchState.initial());
  }

  // ---------------------------------------------------------
  // Request lifecycle
  // ---------------------------------------------------------

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _debounce = null;

    ++_requestGeneration;

    await super.close();
  }
}
