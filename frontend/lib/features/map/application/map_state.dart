import '../domain/map_country_data.dart';
import '../domain/map_destination_status.dart';
import '../domain/map_country_preview.dart';
import '../domain/map_city_data.dart';
import '../domain/map_search_destination.dart';
import '../domain/map_airport_data.dart';
import '../domain/map_flight_route.dart';
import '../domain/map_layer_visibility.dart';

enum MapPhase { initial, loading, ready, failure }

enum MapAirportPhase { initial, loading, ready, failure }

/// Valid empty GeoJSON used before flight geography is loaded.
///
/// Keeping a valid FeatureCollection allows the MapLibre source
/// to initialize even when the user has no completed flights.
const String emptyFlightRoutesGeoJson =
    '{"type":"FeatureCollection","features":[]}';

class MapState {
  const MapState({
    this.phase = MapPhase.initial,
    this.countryData,
    this.countryPreviews = const {},
    this.activeStatus = MapDestinationStatus.visited,
    this.selectedCountryCode,
    this.selectedCityId,
    this.cities = const {},
    this.selectedSearchDestination,
    this.airports = const {},
    this.airportPhase = MapAirportPhase.initial,
    this.airportErrorMessage,
    this.flightRoutes = const [],
    this.flightRoutesGeoJson = emptyFlightRoutesGeoJson,
    this.selectedFlightRouteId,
    this.layerVisibility = const MapLayerVisibility(),
    this.errorMessage,
  });

  final MapPhase phase;

  /// Last successfully loaded country status projection.
  final MapCountryData? countryData;

  /// Read-only country summaries indexed by country code.
  final Map<String, MapCountryPreview> countryPreviews;

  final MapDestinationStatus activeStatus;

  final String? selectedCountryCode;

  /// Currently selected city, identified by its catalog ID.
  ///
  /// Geographic selection is mutually exclusive: selecting a city
  /// clears the previously selected country.
  final int? selectedCityId;

  /// Geographic city projections indexed by catalog city ID.
  ///
  /// Contains all cities associated with recorded visits,
  /// city residences or explicit city wishlist entries.
  final Map<int, MapCityData> cities;

  final String? errorMessage;
  // Catalog destination selected through geographic search.
  ///
  /// This is a temporary selection independent of personal
  /// travel records and the active visualization filter.
  ///
  /// Country and city selections retain their existing identifiers.
  /// Airports are represented exclusively by this destination.
  final MapSearchDestination? selectedSearchDestination;

  /// Airports used in completed personal flights.
  ///
  /// Indexed by the shared airport catalog ID.
  /// This projection does not imply country or city visits.
  final Map<int, MapAirportData> airports;

  /// Independent loading status of the flight airport projection.
  final MapAirportPhase airportPhase;

  /// Last airport loading error, if any.
  final String? airportErrorMessage;

  /// Unique undirected connections derived from completed flights.
  ///
  /// Each connection preserves the IDs and original directions
  /// of its individual flight records.
  ///
  /// Repeated flights between the same airports produce one
  /// connection, regardless of their direction.
  ///
  /// This is read-only presentation data.
  final List<MapFlightRoute> flightRoutes;

  /// Geographic representation of unique completed-flight routes.
  ///
  /// Produced from the same flight and airport catalog snapshot
  /// as [airports] and [flightRoutes].
  ///
  /// Always contains a valid GeoJSON FeatureCollection.
  ///
  /// Repeated flights do not produce additional features or
  /// change the visual weight of a route.
  final String flightRoutesGeoJson;

  /// Currently selected completed-flight connection.
  ///
  /// Uses the direction-independent route identity produced by
  /// buildMapFlightRouteProjection(), e.g. "10:20".
  ///
  /// This is presentation state only and never represents
  /// a persisted route record.
  final String? selectedFlightRouteId;

  /// User-controlled visibility of geographic map layers.
  ///
  /// Independent of the active Visited / Lived / Wishlist status.
  final MapLayerVisibility layerVisibility;

  bool get hasData => countryData != null;

  /// The currently selected unique flight connection.
  ///
  /// Returns null when no route is selected or when the selected
  /// connection is no longer available in the loaded projection.
  ///
  /// Never performs repository requests.
  MapFlightRoute? get selectedFlightRoute {
    final routeId = selectedFlightRouteId;

    if (routeId == null) {
      return null;
    }

    for (final route in flightRoutes) {
      if (route.id == routeId) {
        return route;
      }
    }

    return null;
  }

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

  /// Geographic projection of the currently selected city.
  ///
  /// Returns null when no city is selected or when the selected
  /// city is no longer available in the loaded projection.
  MapCityData? get selectedCity {
    final cityId = selectedCityId;

    if (cityId == null) return null;

    return cities[cityId];
  }

  MapState copyWith({
    MapPhase? phase,
    MapCountryData? countryData,
    Map<String, MapCountryPreview>? countryPreviews,
    MapDestinationStatus? activeStatus,
    String? selectedCountryCode,
    bool clearSelectedCountry = false,
    int? selectedCityId,
    bool clearSelectedCity = false,
    Map<int, MapCityData>? cities,
    String? errorMessage,
    bool clearError = false,
    MapSearchDestination? selectedSearchDestination,
    bool clearSelectedSearchDestination = false,
    Map<int, MapAirportData>? airports,
    List<MapFlightRoute>? flightRoutes,
    String? flightRoutesGeoJson,
    MapAirportPhase? airportPhase,
    String? selectedFlightRouteId,
    bool clearSelectedFlightRoute = false,
    String? airportErrorMessage,
    bool clearAirportError = false,
    MapLayerVisibility? layerVisibility,
  }) {
    return MapState(
      phase: phase ?? this.phase,
      countryData: countryData ?? this.countryData,
      countryPreviews: countryPreviews ?? this.countryPreviews,
      activeStatus: activeStatus ?? this.activeStatus,
      selectedCountryCode: clearSelectedCountry
          ? null
          : selectedCountryCode ?? this.selectedCountryCode,
      selectedCityId: clearSelectedCity
          ? null
          : selectedCityId ?? this.selectedCityId,
      cities: cities ?? this.cities,
      selectedSearchDestination: clearSelectedSearchDestination
          ? null
          : selectedSearchDestination ?? this.selectedSearchDestination,
      airports: airports ?? this.airports,
      flightRoutes: flightRoutes ?? this.flightRoutes,
      flightRoutesGeoJson: flightRoutesGeoJson ?? this.flightRoutesGeoJson,
      airportPhase: airportPhase ?? this.airportPhase,
      airportErrorMessage: clearAirportError
          ? null
          : airportErrorMessage ?? this.airportErrorMessage,
      selectedFlightRouteId: clearSelectedFlightRoute
          ? null
          : selectedFlightRouteId ?? this.selectedFlightRouteId,
      layerVisibility: layerVisibility ?? this.layerVisibility,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
