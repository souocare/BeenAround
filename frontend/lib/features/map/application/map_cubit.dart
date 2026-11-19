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

/// Manages the authenticated user's geographic travel visualization.
///
/// Country and city projections are derived from existing travel records.
/// Map selection and filtering never modify persisted travel data.
///
/// Data loading and geographic projection are independent of MapLibre.
class MapCubit extends Cubit<MapState> {
  MapCubit({
    required CountriesRepository countriesRepository,
    required CityVisitsRepository cityVisitsRepository,
    required ResidenceRepository residenceRepository,
    required WishlistRepository wishlistRepository,
    required MapCountryProjection countryProjection,
    required MapCityProjection cityProjection,
  }) : _countriesRepository = countriesRepository,
       _cityVisitsRepository = cityVisitsRepository,
       _residenceRepository = residenceRepository,
       _wishlistRepository = wishlistRepository,
       _countryProjection = countryProjection,
       _cityProjection = cityProjection,
       super(const MapState());

  final CountriesRepository _countriesRepository;
  final CityVisitsRepository _cityVisitsRepository;
  final ResidenceRepository _residenceRepository;
  final WishlistRepository _wishlistRepository;

  final MapCountryProjection _countryProjection;
  final MapCityProjection _cityProjection;

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
        state.selectedSearchDestination == null) {
      return;
    }

    emit(
      state.copyWith(
        selectedCountryCode: normalizedCode,
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
        state.selectedSearchDestination == null) {
      return;
    }

    emit(
      state.copyWith(
        selectedCityId: cityId,
        clearSelectedCountry: true,
        clearSelectedSearchDestination: true,
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
        state.selectedSearchDestination == null) {
      return;
    }

    emit(
      state.copyWith(
        clearSelectedCountry: true,
        clearSelectedCity: true,
        clearSelectedSearchDestination: true,
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

    emit(state.copyWith(activeStatus: status));
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
