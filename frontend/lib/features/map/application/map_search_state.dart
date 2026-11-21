import 'map_search_results.dart';

/// Lifecycle of a geographic catalog search.
enum MapSearchPhase { idle, waiting, loading, ready, failure }

/// Immutable presentation state for geographic search.
///
/// Search results are independent of the authenticated user's
/// travel history, map filters and geographic selection.
class MapSearchState {
  MapSearchState({
    required this.query,
    required this.phase,
    required this.results,
    Set<MapSearchCategory> pendingCategories = const {},
  }) : pendingCategories = Set.unmodifiable(pendingCategories);

  factory MapSearchState.initial() {
    return MapSearchState(
      query: '',
      phase: MapSearchPhase.idle,
      results: MapSearchResults(),
    );
  }

  final String query;
  final MapSearchPhase phase;
  final MapSearchResults results;

  /// Catalog categories that have not completed their requests.
  ///
  /// Available results remain visible while other categories
  /// are still pending.
  final Set<MapSearchCategory> pendingCategories;

  bool get isIdle => phase == MapSearchPhase.idle;

  bool get isSearching =>
      phase == MapSearchPhase.waiting || phase == MapSearchPhase.loading;

  bool get hasResults => results.hasResults;

  bool get hasErrors => results.hasErrors;

  bool get hasPendingCategories => pendingCategories.isNotEmpty;

  bool isCategoryPending(MapSearchCategory category) =>
      pendingCategories.contains(category);
}
