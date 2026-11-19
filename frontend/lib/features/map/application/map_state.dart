import '../domain/map_country_data.dart';
import '../domain/map_destination_status.dart';
import '../domain/map_country_preview.dart';
import '../domain/map_city_data.dart';

enum MapPhase { initial, loading, ready, failure }

class MapState {
  const MapState({
    this.phase = MapPhase.initial,
    this.countryData,
    this.countryPreviews = const {},
    this.activeStatus = MapDestinationStatus.visited,
    this.selectedCountryCode,
    this.cities = const {},
    this.errorMessage,
  });

  final MapPhase phase;

  /// Last successfully loaded country status projection.
  final MapCountryData? countryData;

  /// Read-only country summaries indexed by country code.
  final Map<String, MapCountryPreview> countryPreviews;

  final MapDestinationStatus activeStatus;

  final String? selectedCountryCode;

  /// Geographic city projections indexed by catalog city ID.
  ///
  /// Contains all cities associated with recorded visits,
  /// city residences or explicit city wishlist entries.
  final Map<int, MapCityData> cities;

  final String? errorMessage;

  bool get hasData => countryData != null;

  Set<String> get highlightedCountryCodes {
    return countryData?.countriesFor(activeStatus) ?? const <String>{};
  }

  /// Cities matching the currently active visualization status.
  List<MapCityData> get visibleCities {
    return List.unmodifiable(
      cities.values.where((city) => city.matchesStatus(activeStatus)),
    );
  }

  /// Preview for the currently selected country.
  ///
  /// Null when nothing is selected or when the country is not
  /// available in the loaded catalogue.
  MapCountryPreview? get selectedCountryPreview {
    final code = selectedCountryCode;

    if (code == null) return null;

    return countryPreviews[code];
  }

  MapState copyWith({
    MapPhase? phase,
    MapCountryData? countryData,
    Map<String, MapCountryPreview>? countryPreviews,
    MapDestinationStatus? activeStatus,
    String? selectedCountryCode,
    bool clearSelectedCountry = false,
    Map<int, MapCityData>? cities,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MapState(
      phase: phase ?? this.phase,
      countryData: countryData ?? this.countryData,
      countryPreviews: countryPreviews ?? this.countryPreviews,
      activeStatus: activeStatus ?? this.activeStatus,
      selectedCountryCode: clearSelectedCountry
          ? null
          : selectedCountryCode ?? this.selectedCountryCode,
      cities: cities ?? this.cities,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
