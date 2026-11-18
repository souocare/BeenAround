import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/countries_repository.dart';
import '../../residences/domain/residence_repository.dart';
import '../../wishlist/domain/wishlist_repository.dart';
import '../domain/map_destination_status.dart';
import 'map_country_projection.dart';
import 'map_state.dart';
import 'map_country_preview_projection.dart';
import '../domain/map_country_preview.dart';

/// Manages the authenticated user's country visualization data.
///
/// Data loading and geographic projection are independent of MapLibre.
class MapCubit extends Cubit<MapState> {
  MapCubit({
    required CountriesRepository countriesRepository,
    required ResidenceRepository residenceRepository,
    required WishlistRepository wishlistRepository,
    required MapCountryProjection countryProjection,
  }) : _countriesRepository = countriesRepository,
       _residenceRepository = residenceRepository,
       _wishlistRepository = wishlistRepository,
       _countryProjection = countryProjection,
       super(const MapState());

  final CountriesRepository _countriesRepository;
  final ResidenceRepository _residenceRepository;
  final WishlistRepository _wishlistRepository;
  final MapCountryProjection _countryProjection;

  int _requestGeneration = 0;

  Future<void> load() async {
    final generation = ++_requestGeneration;

    emit(state.copyWith(phase: MapPhase.loading, clearError: true));

    try {
      final visits = await _countriesRepository.getCountryVisits();

      if (!_isCurrent(generation)) return;

      final residences = await _residenceRepository.getResidences();

      if (!_isCurrent(generation)) return;

      final wishlistEntries = await _wishlistRepository.getWishlistEntries();

      if (!_isCurrent(generation)) return;

      // Country catalogue is needed to resolve names and provide
      // previews even for countries without any travel records.
      final countries = await _countriesRepository.getCountries();

      if (!_isCurrent(generation)) return;

      final countryData = await _countryProjection.build(
        visits: visits,
        residences: residences,
        wishlistEntries: wishlistEntries,
      );

      if (!_isCurrent(generation)) return;
      final countryPreviews = Map<String, MapCountryPreview>.unmodifiable({
        for (final country in countries)
          country.code: buildMapCountryPreview(
            country: country,
            visits: visits,
            residences: residences,
            wishlistEntries: wishlistEntries,
            countryData: countryData,
          ),
      });

      emit(
        state.copyWith(
          phase: MapPhase.ready,
          countryData: countryData,
          countryPreviews: countryPreviews,
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

  /// Selects a country for inspection without modifying travel records.
  void selectCountry(String countryCode) {
    final normalizedCode = countryCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return;
    }

    if (state.selectedCountryCode == normalizedCode) {
      return;
    }

    emit(state.copyWith(selectedCountryCode: normalizedCode));
  }

  /// Clears the current geographic selection.
  void clearCountrySelection() {
    if (state.selectedCountryCode == null) {
      return;
    }

    emit(state.copyWith(clearSelectedCountry: true));
  }

  Future<void> refresh() => load();

  /// Changes only the visualization mode.
  ///
  /// No API request or geographic projection is performed.
  void selectStatus(MapDestinationStatus status) {
    if (state.activeStatus == status) return;

    emit(state.copyWith(activeStatus: status));
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
