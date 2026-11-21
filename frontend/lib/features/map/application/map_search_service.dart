import '../../explore/data/countries_repository.dart';
import '../../explore/domain/country.dart';
import '../../flights/domain/airport_repository.dart';
import '../../geography/domain/city_repository.dart';
import '../../geography/domain/city_sort.dart';

import '../domain/map_search_destination.dart';
import 'map_search_results.dart';

/// Called whenever one geographic catalog finishes searching.
///
/// The completed set includes successful and failed categories.
typedef MapSearchProgressCallback =
    void Function(
      MapSearchResults results,
      Set<MapSearchCategory> completedCategories,
    );

/// Searches the shared geographic catalogs used by the Map.
///
/// The service is independent of MapLibre, user travel records,
/// application state and presentation widgets.
class MapSearchService {
  MapSearchService({
    required CountriesRepository countriesRepository,
    required CityRepository cityRepository,
    required AirportRepository airportRepository,
  }) : _countriesRepository = countriesRepository,
       _cityRepository = cityRepository,
       _airportRepository = airportRepository;

  static const int _resultLimit = 10;

  final CountriesRepository _countriesRepository;
  final CityRepository _cityRepository;
  final AirportRepository _airportRepository;

  /// Cached country catalog request.
  ///
  /// Concurrent searches share the same request. Failed requests
  /// are removed from the cache so a later search can retry.
  Future<List<Country>>? _countriesRequest;

  /// Searches all catalogs and returns their combined results.
  ///
  /// Existing consumers can continue using this method.
  Future<MapSearchResults> search(String query) {
    return _searchInternal(query);
  }

  /// Searches all catalogs concurrently and reports completed
  /// categories as soon as their results become available.
  ///
  /// The callback is invoked after each category completes,
  /// including when its repository request fails.
  ///
  /// The returned Future still completes only after all
  /// categories finish.
  Future<MapSearchResults> searchProgressively(
    String query,
    MapSearchProgressCallback onProgress,
  ) {
    return _searchInternal(query, onProgress: onProgress);
  }

  Future<MapSearchResults> _searchInternal(
    String query, {
    MapSearchProgressCallback? onProgress,
  }) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return MapSearchResults();
    }

    var countries = <MapSearchDestination>[];
    var cities = <MapSearchDestination>[];
    var airports = <MapSearchDestination>[];

    final failedCategories = <MapSearchCategory>{};
    final completedCategories = <MapSearchCategory>{};

    MapSearchResults currentResults() {
      return MapSearchResults(
        countries: countries,
        cities: cities,
        airports: airports,
        failedCategories: failedCategories,
      );
    }

    void categoryCompleted(MapSearchCategory category) {
      completedCategories.add(category);

      onProgress?.call(currentResults(), Set.unmodifiable(completedCategories));
    }

    // All catalog requests start concurrently.
    //
    // Results are reported independently, without waiting
    // for the slowest catalog.
    await Future.wait<void>([
      () async {
        try {
          countries = await _searchCountries(normalizedQuery);
        } catch (_) {
          failedCategories.add(MapSearchCategory.countries);
        } finally {
          categoryCompleted(MapSearchCategory.countries);
        }
      }(),

      () async {
        try {
          final result = await _cityRepository.search(
            query: normalizedQuery,
            sort: CitySort.population,
            limit: _resultLimit,
            offset: 0,
          );

          cities = [
            for (final city in result.items) MapSearchDestination.city(city),
          ];
        } catch (_) {
          failedCategories.add(MapSearchCategory.cities);
        } finally {
          categoryCompleted(MapSearchCategory.cities);
        }
      }(),

      () async {
        try {
          final result = await _airportRepository.search(
            query: normalizedQuery,
            limit: _resultLimit,
            offset: 0,
          );

          airports = [
            for (final airport in result.items)
              MapSearchDestination.airport(airport),
          ];
        } catch (_) {
          failedCategories.add(MapSearchCategory.airports);
        } finally {
          categoryCompleted(MapSearchCategory.airports);
        }
      }(),
    ]);

    return currentResults();
  }

  /// Searches the country catalog by name and ISO codes.
  Future<List<MapSearchDestination>> _searchCountries(String query) async {
    final countries = await _getCountries();

    final normalizedQuery = query.toLowerCase();

    final matches = countries.where((country) {
      return country.name.toLowerCase().contains(normalizedQuery) ||
          country.code.toLowerCase().contains(normalizedQuery) ||
          country.alpha3Code.toLowerCase().contains(normalizedQuery);
    }).toList();

    int relevance(Country country) {
      if (country.code.toLowerCase() == normalizedQuery ||
          country.alpha3Code.toLowerCase() == normalizedQuery ||
          country.name.toLowerCase() == normalizedQuery) {
        return 0;
      }

      if (country.name.toLowerCase().startsWith(normalizedQuery)) {
        return 1;
      }

      return 2;
    }

    matches.sort((a, b) {
      final relevanceComparison = relevance(a).compareTo(relevance(b));

      if (relevanceComparison != 0) {
        return relevanceComparison;
      }

      final nameComparison = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );

      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.code.compareTo(b.code);
    });

    return [
      for (final country in matches.take(_resultLimit))
        MapSearchDestination.country(code: country.code, name: country.name),
    ];
  }

  /// Loads the country catalog once per service instance.
  ///
  /// In-flight requests are reused. Failed requests are not cached.
  Future<List<Country>> _getCountries() async {
    final request = _countriesRequest ??= _countriesRepository.getCountries();

    try {
      return await request;
    } catch (_) {
      if (identical(_countriesRequest, request)) {
        _countriesRequest = null;
      }

      rethrow;
    }
  }
}
