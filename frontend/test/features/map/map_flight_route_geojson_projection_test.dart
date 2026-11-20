import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/map/application/map_flight_route_geojson_projection.dart';
import 'package:beenaround/features/map/domain/map_flight_route.dart';

void main() {
  Airport airport({
    required int id,
    required double? latitude,
    required double? longitude,
  }) {
    return Airport(
      id: id,
      ident: 'TEST$id',
      name: 'Test Airport $id',
      type: 'large_airport',
      scheduledService: true,
      latitude: latitude,
      longitude: longitude,
    );
  }

  MapFlightRoute route({
    int firstAirportId = 10,
    int secondAirportId = 20,
    List<MapFlightRouteFlight>? flights,
  }) {
    return MapFlightRoute(
      firstAirportId: firstAirportId,
      secondAirportId: secondAirportId,
      flights:
          flights ??
          const [
            MapFlightRouteFlight(
              flightId: 'F1',
              departureAirportId: 10,
              arrivalAirportId: 20,
            ),
          ],
    );
  }

  Map<String, dynamic> decodeProjection(String geoJson) {
    return jsonDecode(geoJson) as Map<String, dynamic>;
  }

  List<dynamic> features(String geoJson) {
    return decodeProjection(geoJson)['features'] as List<dynamic>;
  }

  List<dynamic> routeLines(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;

    return geometry['coordinates'] as List<dynamic>;
  }

  group('buildMapFlightRouteGeoJson', () {
    test('returns an empty FeatureCollection without routes', () {
      final result = decodeProjection(
        buildMapFlightRouteGeoJson(routes: const [], airports: const {}),
      );

      expect(result['type'], 'FeatureCollection');
      expect(result['features'], isEmpty);
    });

    test('creates one MultiLineString for a valid route', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
      );

      final projectedFeatures = features(result);

      expect(projectedFeatures, hasLength(1));

      final feature = projectedFeatures.single as Map<String, dynamic>;

      expect(feature['type'], 'Feature');

      final properties = feature['properties'] as Map<String, dynamic>;

      expect(properties['route_id'], '10:20');
      expect(properties['first_airport_id'], 10);
      expect(properties['second_airport_id'], 20);

      final geometry = feature['geometry'] as Map<String, dynamic>;

      expect(geometry['type'], 'MultiLineString');

      final lines = routeLines(feature);

      expect(lines, hasLength(1));

      // FlightRouteGeometry uses 64 segments by default,
      // producing 65 points.
      expect(lines.single, hasLength(65));
    });

    test('preserves geographic endpoints', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
      );

      final feature = features(result).single as Map<String, dynamic>;

      final line = routeLines(feature).single as List<dynamic>;

      final first = line.first as List<dynamic>;
      final last = line.last as List<dynamic>;

      expect(first[0], closeTo(-9.1342, 0.000001));
      expect(first[1], closeTo(38.7742, 0.000001));

      expect(last[0], closeTo(-3.5676, 0.000001));
      expect(last[1], closeTo(40.4983, 0.000001));
    });

    test('skips routes with unresolved airports', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {10: airport(id: 10, latitude: 38.7742, longitude: -9.1342)},
      );

      expect(features(result), isEmpty);
    });

    test('skips routes with missing coordinates', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: null, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
      );

      expect(features(result), isEmpty);
    });

    test('skips routes with invalid coordinates', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 95, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
      );

      expect(features(result), isEmpty);
    });

    test('skips routes without geographic extent', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 38.7742, longitude: -9.1342),
        },
      );

      expect(features(result), isEmpty);
    });

    test('creates one feature for repeated flights', () {
      final repeatedRoute = route(
        flights: const [
          MapFlightRouteFlight(
            flightId: 'F1',
            departureAirportId: 10,
            arrivalAirportId: 20,
          ),
          MapFlightRouteFlight(
            flightId: 'F2',
            departureAirportId: 20,
            arrivalAirportId: 10,
          ),
          MapFlightRouteFlight(
            flightId: 'F3',
            departureAirportId: 10,
            arrivalAirportId: 20,
          ),
        ],
      );

      final result = buildMapFlightRouteGeoJson(
        routes: [repeatedRoute],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
      );

      expect(features(result), hasLength(1));

      final feature = features(result).single as Map<String, dynamic>;

      final properties = feature['properties'] as Map<String, dynamic>;

      // The styling geometry is independent of flight count.
      expect(properties.containsKey('flight_count'), isFalse);
    });

    test('splits antimeridian-crossing routes', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 35, longitude: 179),
          20: airport(id: 20, latitude: 35, longitude: -179),
        },
      );

      final feature = features(result).single as Map<String, dynamic>;

      final lines = routeLines(feature);

      expect(lines, hasLength(2));

      // No individual line may jump across the world.
      for (final rawLine in lines) {
        final line = rawLine as List<dynamic>;

        expect(line.length, greaterThanOrEqualTo(2));

        for (var i = 1; i < line.length; i++) {
          final previous = line[i - 1] as List<dynamic>;
          final current = line[i] as List<dynamic>;

          final previousLongitude = previous[0] as num;
          final currentLongitude = current[0] as num;

          expect(
            (currentLongitude - previousLongitude).abs(),
            lessThanOrEqualTo(180),
          );
        }
      }
    });

    test('handles westward antimeridian crossings', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: -20, longitude: -179),
          20: airport(id: 20, latitude: -20, longitude: 179),
        },
      );

      final feature = features(result).single as Map<String, dynamic>;

      expect(routeLines(feature), hasLength(2));
    });

    test('supports multiple independent routes', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [
          route(firstAirportId: 10, secondAirportId: 20),
          route(firstAirportId: 10, secondAirportId: 30),
        ],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
          30: airport(id: 30, latitude: 51.4700, longitude: -0.4543),
        },
      );

      expect(features(result), hasLength(2));
    });

    test('produces deterministic feature ordering', () {
      final airports = {
        10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
        20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        30: airport(id: 30, latitude: 51.4700, longitude: -0.4543),
      };

      final first = buildMapFlightRouteGeoJson(
        routes: [
          route(firstAirportId: 10, secondAirportId: 30),
          route(firstAirportId: 10, secondAirportId: 20),
        ],
        airports: airports,
      );

      final second = buildMapFlightRouteGeoJson(
        routes: [
          route(firstAirportId: 10, secondAirportId: 20),
          route(firstAirportId: 10, secondAirportId: 30),
        ],
        airports: airports,
      );

      expect(first, second);
    });

    test('supports configurable great-circle resolution', () {
      final result = buildMapFlightRouteGeoJson(
        routes: [route()],
        airports: {
          10: airport(id: 10, latitude: 38.7742, longitude: -9.1342),
          20: airport(id: 20, latitude: 40.4983, longitude: -3.5676),
        },
        segments: 16,
      );

      final feature = features(result).single as Map<String, dynamic>;

      final lines = routeLines(feature);

      expect(lines.single, hasLength(17));
    });

    test('rejects invalid segment resolution', () {
      expect(
        () => buildMapFlightRouteGeoJson(
          routes: const [],
          airports: const {},
          segments: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
