import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_state.dart';
import 'package:beenaround/features/map/domain/map_flight_route.dart';

void main() {
  const route = MapFlightRoute(
    firstAirportId: 10,
    secondAirportId: 20,
    flights: [
      MapFlightRouteFlight(
        flightId: 'F1',
        departureAirportId: 10,
        arrivalAirportId: 20,
      ),
    ],
  );

  const routeGeoJson =
      '{"type":"FeatureCollection","features":['
      '{"type":"Feature","properties":{"route_id":"10:20"},'
      '"geometry":{"type":"MultiLineString",'
      '"coordinates":[[[0,0],[1,1]]]}}]}';

  group('MapState flight route projections', () {
    test('starts with empty geographic flight routes', () {
      const state = MapState();

      expect(state.flightRoutes, isEmpty);
      expect(state.airports, isEmpty);
      expect(state.airportPhase, MapAirportPhase.initial);

      final geoJson =
          jsonDecode(state.flightRoutesGeoJson) as Map<String, dynamic>;

      expect(geoJson['type'], 'FeatureCollection');
      expect(geoJson['features'], isEmpty);
    });

    test('copyWith updates route metadata and geometry together', () {
      const initial = MapState();

      final updated = initial.copyWith(
        flightRoutes: const [route],
        flightRoutesGeoJson: routeGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      expect(updated.flightRoutes, hasLength(1));
      expect(updated.flightRoutes.single.id, '10:20');
      expect(updated.flightRoutes.single.flightCount, 1);
      expect(updated.flightRoutesGeoJson, routeGeoJson);
      expect(updated.airportPhase, MapAirportPhase.ready);
    });

    test('unrelated state updates preserve existing routes', () {
      final loaded = const MapState().copyWith(
        flightRoutes: const [route],
        flightRoutesGeoJson: routeGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      final updated = loaded.copyWith(phase: MapPhase.loading);

      expect(identical(updated.flightRoutes, loaded.flightRoutes), isTrue);
      expect(updated.flightRoutesGeoJson, loaded.flightRoutesGeoJson);
      expect(updated.airportPhase, MapAirportPhase.ready);
    });

    test('loading preserves last successful route snapshot', () {
      final loaded = const MapState().copyWith(
        flightRoutes: const [route],
        flightRoutesGeoJson: routeGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      final loading = loaded.copyWith(
        airportPhase: MapAirportPhase.loading,
        clearAirportError: true,
      );

      expect(loading.flightRoutes, hasLength(1));
      expect(loading.flightRoutesGeoJson, routeGeoJson);
      expect(loading.airportPhase, MapAirportPhase.loading);
      expect(loading.airportErrorMessage, isNull);
    });

    test('failure preserves last successful route snapshot', () {
      final loaded = const MapState().copyWith(
        flightRoutes: const [route],
        flightRoutesGeoJson: routeGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      final failed = loaded.copyWith(
        airportPhase: MapAirportPhase.failure,
        airportErrorMessage: 'Unable to load flight geography.',
      );

      expect(failed.flightRoutes, hasLength(1));
      expect(failed.flightRoutesGeoJson, routeGeoJson);
      expect(failed.airportPhase, MapAirportPhase.failure);
      expect(failed.airportErrorMessage, 'Unable to load flight geography.');
    });

    test('successful empty refresh replaces previous routes', () {
      final loaded = const MapState().copyWith(
        flightRoutes: const [route],
        flightRoutesGeoJson: routeGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      final refreshed = loaded.copyWith(
        flightRoutes: const [],
        flightRoutesGeoJson: emptyFlightRoutesGeoJson,
        airportPhase: MapAirportPhase.ready,
      );

      expect(refreshed.flightRoutes, isEmpty);
      expect(refreshed.flightRoutesGeoJson, emptyFlightRoutesGeoJson);
      expect(refreshed.airportPhase, MapAirportPhase.ready);
    });
    test('resolves the selected flight route', () {
      final state = const MapState().copyWith(
        flightRoutes: const [route],
        selectedFlightRouteId: '10:20',
      );

      expect(state.selectedFlightRoute, same(route));
      expect(state.selectedFlightRouteId, '10:20');
    });

    test('returns null for a missing selected flight route', () {
      final state = const MapState().copyWith(
        flightRoutes: const [route],
        selectedFlightRouteId: '30:40',
      );

      expect(state.selectedFlightRoute, isNull);
    });

    test('clears only the selected route when requested', () {
      final state = const MapState().copyWith(
        flightRoutes: const [route],
        selectedFlightRouteId: '10:20',
      );

      final cleared = state.copyWith(clearSelectedFlightRoute: true);

      expect(cleared.selectedFlightRouteId, isNull);
      expect(cleared.selectedFlightRoute, isNull);
      expect(cleared.flightRoutes, same(state.flightRoutes));
    });
  });
}
