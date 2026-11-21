import '../domain/map_airport_data.dart';
import '../domain/map_search_destination.dart';
import 'map_city_panel_projection.dart';
import 'map_state.dart';
import '../domain/map_flight_route.dart';

/// Geographic entity currently eligible for a contextual Map panel.
///
/// This is a presentation-oriented selection result, not a
/// persisted domain entity.
sealed class MapContextPanelSelection {
  const MapContextPanelSelection();

  /// Stable identity used by animated panel transitions.
  String get key;
}

/// Selected country.
///
/// Country previews and related data continue to be resolved
/// through the existing country panel infrastructure.
class MapCountryPanelSelection extends MapContextPanelSelection {
  const MapCountryPanelSelection(this.countryCode);

  final String countryCode;

  @override
  String get key => 'country:$countryCode';
}

/// Selected city with its read-only presentation projection.
class MapCityPanelSelection extends MapContextPanelSelection {
  const MapCityPanelSelection(this.data);

  final MapCityPanelData data;

  @override
  String get key => 'city:${data.cityId}';
}

/// Selected airport with optional completed-flight statistics.
///
/// An airport may exist in the geographic catalog without
/// appearing in the user's completed-flight projection.
///
/// The loading state must be considered separately before
/// presenting the absence of airport data as an empty history.
class MapAirportPanelSelection extends MapContextPanelSelection {
  const MapAirportPanelSelection({
    required this.destination,
    required this.airport,
    required this.airportPhase,
  });

  final MapSearchDestination destination;
  final MapAirportData? airport;
  final MapAirportPhase airportPhase;

  @override
  String get key => destination.id;
}

/// Selected completed-flight connection.
///
/// A route is a direction-independent geographic connection
/// between two airports.
///
/// Individual flights preserve their original direction.
///
/// Airport metadata comes from the existing personal airport
/// projection. No additional repository requests are performed.
class MapFlightRoutePanelSelection extends MapContextPanelSelection {
  const MapFlightRoutePanelSelection({
    required this.route,
    required this.firstAirport,
    required this.secondAirport,
  });

  final MapFlightRoute route;

  final MapAirportData? firstAirport;
  final MapAirportData? secondAirport;

  @override
  String get key => 'flight-route:${route.id}';
}

/// Resolves the active geographic selection into a contextual
/// panel selection.
///
/// The result depends only on the existing MapState.
///
/// No repositories are accessed and no travel records are changed.
MapContextPanelSelection? resolveMapContextPanelSelection(MapState state) {
  // ---------------------------------------------------------------------------
  // Completed-flight route
  //
  // A selected route takes priority over other geographic selections.
  //
  // The MapCubit normally guarantees mutual exclusivity. This
  // defensive ordering also supports consistent presentation when
  // receiving an unexpected intermediate state.
  // ---------------------------------------------------------------------------

  final selectedRoute = state.selectedFlightRoute;

  if (selectedRoute != null) {
    return MapFlightRoutePanelSelection(
      route: selectedRoute,
      firstAirport: state.airports[selectedRoute.firstAirportId],
      secondAirport: state.airports[selectedRoute.secondAirportId],
    );
  }

  // ---------------------------------------------------------------------------
  // Country
  // ---------------------------------------------------------------------------

  final countryCode = state.selectedCountryCode;

  if (countryCode != null && countryCode.trim().isNotEmpty) {
    return MapCountryPanelSelection(countryCode.trim().toUpperCase());
  }

  // ---------------------------------------------------------------------------
  // City
  // ---------------------------------------------------------------------------

  final cityId = state.selectedCityId;

  if (cityId != null && cityId > 0) {
    final destination = state.selectedSearchDestination;

    // Only use catalog metadata when it refers to the
    // currently selected city.
    final matchingDestination =
        destination?.type == MapSearchDestinationType.city &&
            destination?.id == 'city:$cityId'
        ? destination
        : null;

    final data = buildMapCityPanelData(
      city: state.cities[cityId],
      destination: matchingDestination,
    );

    if (data != null) {
      return MapCityPanelSelection(data);
    }
  }

  // ---------------------------------------------------------------------------
  // Airport
  // ---------------------------------------------------------------------------

  final destination = state.selectedSearchDestination;

  if (destination?.type == MapSearchDestinationType.airport) {
    final rawId = destination!.id;

    if (!rawId.startsWith('airport:')) {
      return null;
    }

    final airportId = int.tryParse(rawId.substring('airport:'.length));

    if (airportId == null || airportId <= 0) {
      return null;
    }

    return MapAirportPanelSelection(
      destination: destination,
      airport: state.airports[airportId],
      airportPhase: state.airportPhase,
    );
  }

  return null;
}
