import '../domain/map_search_destination.dart';

/// Geographic catalog categories that can fail independently.
enum MapSearchCategory { countries, cities, airports }

/// Results returned by a unified geographic search.
///
/// Each catalog is searched independently. Successful categories
/// remain available even when another category fails.
class MapSearchResults {
  MapSearchResults({
    List<MapSearchDestination> countries = const [],
    List<MapSearchDestination> cities = const [],
    List<MapSearchDestination> airports = const [],
    Set<MapSearchCategory> failedCategories = const {},
  }) : countries = List.unmodifiable(countries),
       cities = List.unmodifiable(cities),
       airports = List.unmodifiable(airports),
       failedCategories = Set.unmodifiable(failedCategories);

  final List<MapSearchDestination> countries;
  final List<MapSearchDestination> cities;
  final List<MapSearchDestination> airports;

  /// Categories whose repository request failed.
  final Set<MapSearchCategory> failedCategories;

  bool get hasResults =>
      countries.isNotEmpty || cities.isNotEmpty || airports.isNotEmpty;

  bool get hasErrors => failedCategories.isNotEmpty;

  bool get hasNoResults => !hasResults && !hasErrors;

  bool get hasPartialResults => hasResults && hasErrors;

  bool get allFailed =>
      failedCategories.length == MapSearchCategory.values.length;

  /// All destinations in presentation order.
  List<MapSearchDestination> get all =>
      List.unmodifiable([...countries, ...cities, ...airports]);
}
