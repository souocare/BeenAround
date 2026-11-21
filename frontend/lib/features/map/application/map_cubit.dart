import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/countries_repository.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../../residences/domain/residence_repository.dart';
import '../../wishlist/domain/wishlist_repository.dart';

import '../domain/map_country_preview.dart';
import '../domain/map_destination_status.dart';

import 'map_city_projection.dart';
import 'map_country_preview_projection.dart';
import 'map_country_projection.dart';
import 'map_state.dart';
import '../domain/map_search_destination.dart';

import '../../flights/application/flight_catalog_resolver.dart';
import '../../flights/domain/flight.dart';
import '../../flights/domain/flight_repository.dart';

import 'map_airport_projection.dart';
import 'map_flight_route_projection.dart';
import 'map_flight_route_geojson_projection.dart';
import '../domain/map_layer_visibility.dart';

/// Manages the authenticated user's geographic travel visualization.
///
/// Country and city projections are derived from existing travel records.
/// Map selection and filtering never modify persisted travel data.
///
/// Data loading and geographic projection are independent of MapLibre.
class MapCubit extends Cubit<MapState> {
  MapCubit({
    required this._countriesRepository,
    required this._cityVisitsRepository,
    required this._residenceRepository,
    required this._wishlistRepository,
    required this._countryProjection,
    required this._cityProjection,
    required this._flightRepository,
    required this._flightCatalogResolver,
  }) : super(const MapState());

  final CountriesRepository _countriesRepository;
  final CityVisitsRepository _cityVisitsRepository;
  final ResidenceRepository _residenceRepository;
  final WishlistRepository _wishlistRepository;

  final MapCountryProjection _countryProjection;
  final MapCityProjection _cityProjection;
  final FlightRepository _flightRepository;
  final FlightCatalogResolver _flightCatalogResolver;

  int _airportRequestGeneration = 0;

  static const int _flightPageSize = 20;

  int _requestGeneration = 0;

  /// Loads the authenticated user's travel records and builds
  /// read-only geographic projections for countries and cities.
  ///
  /// Previous successful data remains available during refreshes
  /// and when a subsequent load fails.
  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(state.copyWith(phase: MapPhase.loading, clearError: true));

    try {
      // -------------------------------------------------------
      // 1. Country visits
      // -------------------------------------------------------

      final countryVisits = await _countriesRepository.getCountryVisits();

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 2. City visits
      // -------------------------------------------------------

      final cityVisits = await _cityVisitsRepository.getCityVisits();

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 3. Residences
      // -------------------------------------------------------

      final residences = await _residenceRepository.getResidences();

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 4. Global wishlist
      // -------------------------------------------------------

      final wishlistEntries = await _wishlistRepository.getWishlistEntries();

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 5. Country catalogue
      //
      // Required for country identity and previews even when
      // the user has no recorded visits.
      // -------------------------------------------------------

      final countries = await _countriesRepository.getCountries();

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 6. Country geographic projection
      // -------------------------------------------------------

      final countryData = await _countryProjection.build(
        visits: countryVisits,
        residences: residences,
        wishlistEntries: wishlistEntries,
      );

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 7. City geographic projection
      //
      // City coordinates are resolved from the existing city
      // catalogue. Multiple visits produce one geographic city.
      // -------------------------------------------------------

      final cities = await _cityProjection.build(
        visits: cityVisits,
        residences: residences,
        wishlistEntries: wishlistEntries,
      );

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 8. Country previews
      // -------------------------------------------------------

      final countryPreviews = Map<String, MapCountryPreview>.unmodifiable({
        for (final country in countries)
          country.code: buildMapCountryPreview(
            country: country,
            visits: countryVisits,
            residences: residences,
            wishlistEntries: wishlistEntries,
            countryData: countryData,
          ),
      });

      if (!_isCurrent(generation)) return;

      // -------------------------------------------------------
      // 9. Publish geographic data atomically
      //
      // Countries and cities become available together.
      // The active visualization filter and current country
      // selection remain unchanged.
      // -------------------------------------------------------

      emit(
        state.copyWith(
          phase: MapPhase.ready,
          countryData: countryData,
          countryPreviews: countryPreviews,
          cities: cities,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        state.copyWith(phase: MapPhase.failure, errorMessage: error.message),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        state.copyWith(
          phase: MapPhase.failure,
          errorMessage: 'Unable to load your travel map.',
        ),
      );
    }
  }

  // ---------------------------------------------------------
  // Flight airport projection
  // ---------------------------------------------------------

  /// Loads airports used in the authenticated user's
  /// completed flight history.
  ///
  /// This operation is independent of the country/city map load.
  ///
  /// A failure preserves the last successfully loaded airport
  /// projection without affecting the main geographic map.
  Future<void> loadAirports() async {
    if (isClosed) return;

    final generation = ++_airportRequestGeneration;

    emit(
      state.copyWith(
        airportPhase: MapAirportPhase.loading,
        clearAirportError: true,
      ),
    );

    try {
      final flights = <Flight>[];

      var offset = 0;

      // -------------------------------------------------------
      // 1. Load all completed flights
      //
      // Never project only the first page.
      // -------------------------------------------------------

      while (true) {
        final page = await _flightRepository.getFlights(
          limit: _flightPageSize,
          offset: offset,
          status: FlightStatus.flown,
        );

        if (!_isCurrentAirportRequest(generation)) return;

        // Prevent a malformed pagination response from
        // producing an infinite request loop.
        if (page.items.isEmpty && page.hasMore) {
          throw StateError('Invalid flight pagination response.');
        }

        flights.addAll(page.items);

        if (!page.hasMore) {
          break;
        }

        offset += page.items.length;
      }

      // -------------------------------------------------------
      // 2. Collect unique airport IDs
      // -------------------------------------------------------

      final airportIds = <int>{};

      for (final flight in flights) {
        if (!flight.isFlown) continue;

        airportIds.add(flight.departureAirportId);
        airportIds.add(flight.arrivalAirportId);
      }

      // -------------------------------------------------------
      // 3. Resolve airport catalog metadata
      // -------------------------------------------------------

      final airports = await _flightCatalogResolver.resolveAirports(airportIds);

      if (!_isCurrentAirportRequest(generation)) return;

      // -------------------------------------------------------
      // 4. Build completed-flight geographic projections.
      //
      // Both projections use the same completed-flight snapshot
      // and the same resolved airport catalog.
      //
      // No additional repository requests are performed.
      // -------------------------------------------------------

      final airportProjection = buildMapAirportProjection(
        flights: flights,
        airports: airports,
      );

      final routeProjection = buildMapFlightRouteProjection(flights: flights);

      // -------------------------------------------------------
      // 5. Build antimeridian-safe route geometry.
      //
      // The geometry contains one feature per unique drawable
      // airport connection.
      //
      // Repeated and reverse-direction flights share the same
      // visual line. Flight counts never affect line styling.
      //
      // Routes without valid resolved coordinates are omitted
      // from GeoJSON but remain in the route projection.
      // -------------------------------------------------------

      final routeGeoJson = buildMapFlightRouteGeoJson(
        routes: routeProjection,
        airports: airports,
      );

      if (!_isCurrentAirportRequest(generation)) return;

      // -------------------------------------------------------
      // 6. Publish complete flight geography atomically.
      //
      // Airports, route metadata and route geometry must belong
      // to the same successful loading generation.
      //
      // Existing country and city data, geographic selection
      // and active map filters remain unchanged.
      // -------------------------------------------------------
      final selectedRouteId = state.selectedFlightRouteId;

      final selectedRouteStillExists =
          selectedRouteId != null &&
          routeProjection.any((route) => route.id == selectedRouteId);
      emit(
        state.copyWith(
          airports: airportProjection,
          flightRoutes: routeProjection,
          flightRoutesGeoJson: routeGeoJson,
          airportPhase: MapAirportPhase.ready,
          clearAirportError: true,
          clearSelectedFlightRoute:
              selectedRouteId != null && !selectedRouteStillExists,
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrentAirportRequest(generation)) return;

      emit(
        state.copyWith(
          airportPhase: MapAirportPhase.failure,
          airportErrorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrentAirportRequest(generation)) return;

      emit(
        state.copyWith(
          airportPhase: MapAirportPhase.failure,
          airportErrorMessage: 'Unable to load your flight airports.',
        ),
      );
    }
  }

  bool _isCurrentAirportRequest(int generation) {
    return !isClosed && generation == _airportRequestGeneration;
  }

  // ---------------------------------------------------------
  // Geographic selection
  // ---------------------------------------------------------

  /// Selects a country for inspection without modifying travel records.
  ///
  /// Selecting a country clears any previously selected city.
  /// Selects a country without modifying travel records.
  ///
  /// Clears any previous city, airport or catalog selection.
  void selectCountry(String countryCode) {
    if (isClosed) return;

    final normalizedCode = countryCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) return;

    if (state.selectedCountryCode == normalizedCode &&
        state.selectedCityId == null &&
        state.selectedSearchDestination == null &&
        state.selectedFlightRouteId == null) {
      return;
    }

    emit(
      state.copyWith(
        selectedCountryCode: normalizedCode,
        clearSelectedCity: true,
        clearSelectedSearchDestination: true,
        clearSelectedFlightRoute: true,
      ),
    );
  }

  /// Selects a completed-flight connection for contextual inspection.
  ///
  /// Route IDs are direction-independent airport pairs.
  ///
  /// Only routes available in the current personal flight projection
  /// may be selected.
  ///
  /// Selection does not modify flights, visits, wishlists or Trips.
  void selectFlightRoute(String routeId) {
    if (isClosed) return;

    final normalizedId = routeId.trim();

    if (normalizedId.isEmpty) return;

    final exists = state.flightRoutes.any((route) => route.id == normalizedId);

    if (!exists) {
      return;
    }

    if (state.selectedFlightRouteId == normalizedId &&
        state.selectedCountryCode == null &&
        state.selectedCityId == null &&
        state.selectedSearchDestination == null) {
      return;
    }

    emit(
      state.copyWith(
        selectedFlightRouteId: normalizedId,
        clearSelectedCountry: true,
        clearSelectedCity: true,
        clearSelectedSearchDestination: true,
      ),
    );
  }

  /// Selects a city for inspection without modifying travel records.
  ///
  /// Selecting a city clears any previously selected country.
  /// Selects a city from the user's geographic map projection.
  ///
  /// Clears any previous country or catalog selection.
  void selectCity(int cityId) {
    if (isClosed || cityId <= 0) return;

    if (state.selectedCityId == cityId &&
        state.selectedCountryCode == null &&
        state.selectedSearchDestination == null &&
        state.selectedFlightRouteId == null) {
      return;
    }

    emit(
      state.copyWith(
        selectedCityId: cityId,
        clearSelectedCountry: true,
        clearSelectedSearchDestination: true,
        clearSelectedFlightRoute: true,
      ),
    );
  }

  /// Clears the current country selection.
  ///
  /// Does not modify a separately selected city.
  void clearCountrySelection() {
    if (isClosed || state.selectedCountryCode == null) {
      return;
    }

    emit(state.copyWith(clearSelectedCountry: true));
  }

  /// Clears the current city selection.
  ///
  /// Also clears the associated temporary catalog selection,
  /// when the selected search destination is a city.
  void clearCitySelection() {
    if (isClosed || state.selectedCityId == null) {
      return;
    }

    emit(
      state.copyWith(
        clearSelectedCity: true,
        clearSelectedSearchDestination:
            state.selectedSearchDestination?.type ==
            MapSearchDestinationType.city,
      ),
    );
  }

  /// Clears any currently selected geographic destination.
  ///
  /// Includes temporary catalog destinations such as airports.
  void clearSelection() {
    if (isClosed) return;

    if (state.selectedCountryCode == null &&
        state.selectedCityId == null &&
        state.selectedSearchDestination == null &&
        state.selectedFlightRouteId == null) {
      return;
    }

    emit(
      state.copyWith(
        clearSelectedCountry: true,
        clearSelectedCity: true,
        clearSelectedSearchDestination: true,
        clearSelectedFlightRoute: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // Data refresh
  // ---------------------------------------------------------

  /// Reloads travel records and rebuilds geographic projections.
  ///
  /// The current filter and country selection are preserved.
  Future<void> refresh() => load();

  // ---------------------------------------------------------
  // Destination status
  // ---------------------------------------------------------

  /// Changes the active visualization status.
  ///
  /// Country highlighting and visible cities are derived from
  /// the already loaded projections.
  ///
  /// No repository requests or projections are performed.
  void selectStatus(MapDestinationStatus status) {
    if (isClosed || state.activeStatus == status) {
      return;
    }
    // ---------------------------------------------------------------------------
    // Map layer visibility
    // ---------------------------------------------------------------------------

    /// Updates geographic layer visibility without reloading or
    /// modifying any travel records.
    ///
    /// Destination-status filtering remains independent.
    void setLayerVisibility(MapLayerVisibility visibility) {
      if (isClosed || state.layerVisibility == visibility) {
        return;
      }

      emit(state.copyWith(layerVisibility: visibility));
    }

    /// Controls visibility of country travel-status highlights.
    ///
    /// Neutral world geography remains available.
    void setCountriesVisible(bool visible) {
      setLayerVisibility(state.layerVisibility.copyWith(countries: visible));
    }

    /// Controls visibility of normal geographic city markers.
    void setCitiesVisible(bool visible) {
      setLayerVisibility(state.layerVisibility.copyWith(cities: visible));
    }

    /// Controls visibility of completed-flight airport markers.
    void setAirportsVisible(bool visible) {
      setLayerVisibility(state.layerVisibility.copyWith(airports: visible));
    }

    /// Controls visibility of completed-flight route geometry.
    ///
    /// This also controls the selected-route visual highlight,
    /// without clearing the current route selection.

    emit(state.copyWith(activeStatus: status));
  }

  // ---------------------------------------------------------------------------
  // Map layer visibility
  // ---------------------------------------------------------------------------

  /// Updates geographic layer visibility without reloading
  /// or modifying any travel records.
  void setLayerVisibility(MapLayerVisibility visibility) {
    if (isClosed || state.layerVisibility == visibility) {
      return;
    }

    emit(state.copyWith(layerVisibility: visibility));
  }

  /// Controls visibility of country travel-status highlights.
  void setCountriesVisible(bool visible) {
    setLayerVisibility(state.layerVisibility.copyWith(countries: visible));
  }

  /// Controls visibility of normal city markers.
  void setCitiesVisible(bool visible) {
    setLayerVisibility(state.layerVisibility.copyWith(cities: visible));
  }

  /// Controls visibility of completed-flight airport markers.
  void setAirportsVisible(bool visible) {
    setLayerVisibility(state.layerVisibility.copyWith(airports: visible));
  }

  /// Controls visibility of completed-flight routes.
  void setFlightRoutesVisible(bool visible) {
    setLayerVisibility(state.layerVisibility.copyWith(flightRoutes: visible));
  }

  /// Selects a destination from the shared geographic catalog.
  ///
  /// Search selection is read-only and never modifies visits,
  /// residences, wishlists or Trips.
  ///
  /// Only one geographic destination can be selected at a time.
  void selectSearchDestination(MapSearchDestination destination) {
    if (isClosed) return;

    switch (destination.type) {
      // -------------------------------------------------------
      // Country
      // -------------------------------------------------------

      case MapSearchDestinationType.country:
        final countryCode = destination.countryCode?.trim().toUpperCase();

        if (countryCode == null || countryCode.isEmpty) {
          return;
        }

        // Countries already have a geographic selection model.
        // Reuse it instead of duplicating country state.
        selectCountry(countryCode);

      // -------------------------------------------------------
      // City
      // -------------------------------------------------------

      case MapSearchDestinationType.city:
        final rawCityId = destination.id;

        if (!rawCityId.startsWith('city:')) {
          return;
        }

        final cityId = int.tryParse(rawCityId.substring(5));

        if (cityId == null || cityId <= 0 || !destination.hasCoordinates) {
          return;
        }

        if (state.selectedCityId == cityId &&
            state.selectedCountryCode == null &&
            state.selectedSearchDestination?.id == destination.id) {
          return;
        }

        emit(
          state.copyWith(
            selectedCityId: cityId,
            selectedSearchDestination: destination,
            clearSelectedFlightRoute: true,
            clearSelectedCountry: true,
          ),
        );

      // -------------------------------------------------------
      // Airport
      // -------------------------------------------------------

      case MapSearchDestinationType.airport:
        // Airports without coordinates cannot currently be
        // positioned on the map.
        //
        // Their search results remain available, but geographic
        // selection requires valid coordinates.
        if (!destination.hasCoordinates) {
          return;
        }

        if (state.selectedSearchDestination?.id == destination.id &&
            state.selectedCountryCode == null &&
            state.selectedCityId == null) {
          return;
        }

        emit(
          state.copyWith(
            selectedSearchDestination: destination,
            clearSelectedCountry: true,
            clearSelectedCity: true,
          ),
        );
    }
  }

  // ---------------------------------------------------------
  // Request lifecycle
  // ---------------------------------------------------------

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;
    return super.close();
  }
}
