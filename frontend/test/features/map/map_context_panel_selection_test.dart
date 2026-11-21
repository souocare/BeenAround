import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_context_panel_selection.dart';
import 'package:beenaround/features/map/application/map_state.dart';
import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';
import 'package:beenaround/features/map/domain/map_flight_route.dart';

const cityDestination = MapSearchDestination(
  type: MapSearchDestinationType.city,
  id: 'city:10',
  title: 'Lisbon',
  subtitle: 'Portugal',
  countryCode: 'PT',
  latitude: 38.7223,
  longitude: -9.1393,
);

const airportDestination = MapSearchDestination(
  type: MapSearchDestinationType.airport,
  id: 'airport:25',
  title: 'Humberto Delgado Airport',
  subtitle: 'LIS · Lisbon, Portugal',
  countryCode: 'PT',
  latitude: 38.7742,
  longitude: -9.1342,
  airportCode: 'LIS',
  airportLocation: 'Lisbon, Portugal',
);

const recordedCity = MapCityData(
  cityId: 10,
  name: 'Lisbon',
  countryCode: 'PT',
  countryName: 'Portugal',
  latitude: 38.7223,
  longitude: -9.1393,
  visitCount: 3,
  residenceCount: 1,
  isWishlisted: true,
);

const recordedAirport = MapAirportData(
  airportId: 25,
  code: 'LIS',
  name: 'Humberto Delgado Airport',
  countryCode: 'PT',
  latitude: 38.7742,
  longitude: -9.1342,
  departureCount: 5,
  arrivalCount: 3,
  flightCount: 8,
);

void main() {
  group('resolveMapContextPanelSelection', () {
    test('returns null without a geographic selection', () {
      const state = MapState();

      expect(resolveMapContextPanelSelection(state), isNull);
    });

    test('resolves a selected country', () {
      const state = MapState(selectedCountryCode: 'PT');

      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapCountryPanelSelection>());
      expect(selection!.key, 'country:PT');

      final country = selection as MapCountryPanelSelection;

      expect(country.countryCode, 'PT');
    });

    test('resolves a city selected directly from the map', () {
      const state = MapState(selectedCityId: 10, cities: {10: recordedCity});

      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapCityPanelSelection>());
      expect(selection!.key, 'city:10');

      final city = selection as MapCityPanelSelection;

      expect(city.data.name, 'Lisbon');
      expect(city.data.visitCount, 3);
      expect(city.data.residenceCount, 1);
      expect(city.data.isWishlisted, isTrue);
    });

    test('preserves personal city history when selected by search', () {
      const state = MapState(
        selectedCityId: 10,
        selectedSearchDestination: cityDestination,
        cities: {10: recordedCity},
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapCityPanelSelection;

      expect(selection.data.visitCount, 3);
      expect(selection.data.residenceCount, 1);
      expect(selection.data.isWishlisted, isTrue);
    });

    test('resolves a catalog-only city', () {
      const state = MapState(
        selectedCityId: 10,
        selectedSearchDestination: cityDestination,
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapCityPanelSelection;

      expect(selection.data.cityId, 10);
      expect(selection.data.name, 'Lisbon');
      expect(selection.data.visitCount, 0);
      expect(selection.data.residenceCount, 0);
      expect(selection.data.hasAnyStatus, isFalse);
    });

    test('does not use unrelated catalog metadata for a selected city', () {
      const state = MapState(
        selectedCityId: 10,
        selectedSearchDestination: MapSearchDestination(
          type: MapSearchDestinationType.city,
          id: 'city:99',
          title: 'Another city',
          subtitle: 'Another country',
        ),
        cities: {10: recordedCity},
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapCityPanelSelection;

      expect(selection.data.cityId, 10);
      expect(selection.data.name, 'Lisbon');
    });

    test('resolves an airport with recorded flights', () {
      const state = MapState(
        selectedSearchDestination: airportDestination,
        airports: {25: recordedAirport},
        airportPhase: MapAirportPhase.ready,
      );

      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapAirportPanelSelection>());
      expect(selection!.key, 'airport:25');

      final airport = selection as MapAirportPanelSelection;

      expect(airport.airport?.flightCount, 8);
      expect(airport.airport?.departureCount, 5);
      expect(airport.airport?.arrivalCount, 3);
      expect(airport.airportPhase, MapAirportPhase.ready);
    });

    test('resolves an unused airport when projection is ready', () {
      const state = MapState(
        selectedSearchDestination: airportDestination,
        airportPhase: MapAirportPhase.ready,
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapAirportPanelSelection;

      expect(selection.airport, isNull);
      expect(selection.airportPhase, MapAirportPhase.ready);
    });

    test('preserves airport loading state', () {
      const state = MapState(
        selectedSearchDestination: airportDestination,
        airportPhase: MapAirportPhase.loading,
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapAirportPanelSelection;

      expect(selection.airport, isNull);
      expect(selection.airportPhase, MapAirportPhase.loading);
    });

    test('preserves airport failure state', () {
      const state = MapState(
        selectedSearchDestination: airportDestination,
        airportPhase: MapAirportPhase.failure,
      );

      final selection =
          resolveMapContextPanelSelection(state) as MapAirportPanelSelection;

      expect(selection.airport, isNull);
      expect(selection.airportPhase, MapAirportPhase.failure);
    });

    test('rejects malformed airport identifiers', () {
      const state = MapState(
        selectedSearchDestination: MapSearchDestination(
          type: MapSearchDestinationType.airport,
          id: 'airport:invalid',
          title: 'Invalid Airport',
          subtitle: '',
        ),
      );

      expect(resolveMapContextPanelSelection(state), isNull);
    });

    test('rejects unsupported temporary catalog selections', () {
      const state = MapState(
        selectedSearchDestination: MapSearchDestination(
          type: MapSearchDestinationType.country,
          id: 'country:PT',
          title: 'Portugal',
          subtitle: 'PT',
          countryCode: 'PT',
        ),
      );

      // Country selection is represented by selectedCountryCode.
      // A temporary catalog destination alone must not
      // create a second independent country selection.
      expect(resolveMapContextPanelSelection(state), isNull);
    });

    test('keeps country selection as the primary selection', () {
      const state = MapState(
        selectedCountryCode: 'PT',
        selectedCityId: 10,
        selectedSearchDestination: airportDestination,
      );

      // Defensive handling of inconsistent selection state.
      // Normal MapCubit operations enforce mutual exclusivity.
      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapCountryPanelSelection>());
      expect(selection!.key, 'country:PT');
    });
    test('resolves a selected completed-flight route', () {
      const route = MapFlightRoute(
        firstAirportId: 10,
        secondAirportId: 20,
        flights: [
          MapFlightRouteFlight(
            flightId: 'F1',
            departureAirportId: 10,
            arrivalAirportId: 20,
            departureOn: '2025-09-08',
          ),
        ],
      );

      final state = const MapState().copyWith(
        flightRoutes: const [route],
        selectedFlightRouteId: '10:20',
      );

      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapFlightRoutePanelSelection>());

      final routeSelection = selection! as MapFlightRoutePanelSelection;

      expect(routeSelection.key, 'flight-route:10:20');
      expect(routeSelection.route.id, '10:20');
      expect(routeSelection.route.flightCount, 1);

      expect(routeSelection.firstAirport, isNull);
      expect(routeSelection.secondAirport, isNull);
    });
    test('does not resolve a missing flight route', () {
      final state = const MapState().copyWith(selectedFlightRouteId: '999:999');

      expect(resolveMapContextPanelSelection(state), isNull);
    });
    test('does not resolve a missing flight route', () {
      final state = const MapState().copyWith(selectedFlightRouteId: '999:999');

      expect(resolveMapContextPanelSelection(state), isNull);
    });
    test('selected route takes precedence over stale country selection', () {
      const route = MapFlightRoute(
        firstAirportId: 10,
        secondAirportId: 20,
        flights: [],
      );

      final state = const MapState().copyWith(
        selectedCountryCode: 'PT',
        selectedFlightRouteId: '10:20',
        flightRoutes: const [route],
      );

      final selection = resolveMapContextPanelSelection(state);

      expect(selection, isA<MapFlightRoutePanelSelection>());
    });
  });
}
