import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_airport_geojson_projection.dart';
import 'package:beenaround/features/map/application/map_airport_visibility.dart';
import 'package:beenaround/features/map/application/map_search_selection_geojson.dart';
import 'package:beenaround/features/map/application/map_selected_airport_visibility.dart';
import 'package:beenaround/features/map/domain/map_airport_data.dart';
import 'package:beenaround/features/map/domain/map_city_data.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';

MapAirportData makeAirport({
  required int id,
  required String code,
  required double latitude,
  required double longitude,
}) {
  return MapAirportData(
    airportId: id,
    code: code,
    name: '$code Airport',
    countryCode: 'PT',
    latitude: latitude,
    longitude: longitude,
    departureCount: 2,
    arrivalCount: 1,
    flightCount: 3,
  );
}

MapCityData makeCity({
  required int id,
  required double latitude,
  required double longitude,
}) {
  return MapCityData(
    cityId: id,
    name: 'City $id',
    countryCode: 'PT',
    countryName: 'Portugal',
    latitude: latitude,
    longitude: longitude,
    visitCount: 1,
    residenceCount: 0,
    isWishlisted: false,
  );
}

Map<String, dynamic> decodeGeoJson(String value) {
  return jsonDecode(value) as Map<String, dynamic>;
}

/// Runs the same pure projection stages used by TravelMap.
///
/// This intentionally excludes MapLibre's native rendering,
/// camera lifecycle and hit testing.
Map<String, dynamic> buildNormalAirportCollection({
  required List<MapAirportData> airports,
  required List<MapCityData> cities,
  required MapSearchDestination? selection,
  required double zoom,
}) {
  final visible = calculateVisibleMapAirports(
    airports: airports,
    visibleCities: cities,
    zoom: zoom,
  );

  final selectedAirportId = selectedUsedAirportId(
    selectedDestination: selection,
    usedAirports: airports,
  );

  final normal = excludeSelectedMapAirport(
    airports: visible,
    selectedAirportId: selectedAirportId,
  );

  return decodeGeoJson(buildMapAirportGeoJson(airports: normal));
}

Map<String, dynamic> buildSelectedAirportCollection({
  required MapSearchDestination? selection,
  required List<MapAirportData> airports,
}) {
  final selectedAirportId = selectedUsedAirportId(
    selectedDestination: selection,
    usedAirports: airports,
  );

  return decodeGeoJson(
    buildMapSearchSelectionGeoJson(
      destination: selection,
      isUsedAirport: selectedAirportId != null,
    ),
  );
}

List<dynamic> featuresOf(Map<String, dynamic> collection) {
  return collection['features'] as List<dynamic>;
}

void main() {
  final lisbon = makeCity(id: 1, latitude: 38.7223, longitude: -9.1393);

  final lisbonAirport = makeAirport(
    id: 10,
    code: 'LIS',
    latitude: 38.7742,
    longitude: -9.1342,
  );

  final madeiraAirport = makeAirport(
    id: 20,
    code: 'FNC',
    latitude: 32.6979,
    longitude: -16.7745,
  );

  const selectedLisbonAirport = MapSearchDestination(
    type: MapSearchDestinationType.airport,
    id: 'airport:10',
    title: 'Lisbon Airport',
    subtitle: 'LIS',
    latitude: 38.7742,
    longitude: -9.1342,
    airportCode: 'LIS',
  );

  const selectedUnusedAirport = MapSearchDestination(
    type: MapSearchDestinationType.airport,
    id: 'airport:999',
    title: 'Other Airport',
    subtitle: 'ABC',
    latitude: 40,
    longitude: -8,
    airportCode: 'ABC',
  );

  group('Airport selection integration', () {
    test('selected used airport appears only in selection source', () {
      final airports = [lisbonAirport, madeiraAirport];

      final normal = buildNormalAirportCollection(
        airports: airports,
        cities: [lisbon],
        selection: selectedLisbonAirport,
        zoom: 12,
      );

      final selected = buildSelectedAirportCollection(
        selection: selectedLisbonAirport,
        airports: airports,
      );

      final normalIds = featuresOf(
        normal,
      ).map((feature) => feature['id']).toList();

      expect(normalIds, [20]);

      final selectedFeatures = featuresOf(selected);

      expect(selectedFeatures, hasLength(1));

      expect(
        selectedFeatures.single['properties']['destination_id'],
        'airport:10',
      );

      expect(selectedFeatures.single['properties']['is_used_airport'], isTrue);
    });

    test('unused selected airport does not remove used airports', () {
      final airports = [lisbonAirport, madeiraAirport];

      final normal = buildNormalAirportCollection(
        airports: airports,
        cities: const [],
        selection: selectedUnusedAirport,
        zoom: 4,
      );

      final selected = buildSelectedAirportCollection(
        selection: selectedUnusedAirport,
        airports: airports,
      );

      expect(featuresOf(normal).map((feature) => feature['id']).toList(), [
        10,
        20,
      ]);

      expect(
        featuresOf(selected).single['properties']['is_used_airport'],
        isFalse,
      );
    });

    test('selected airport remains in selection source at low zoom', () {
      final airports = [lisbonAirport];

      final normal = buildNormalAirportCollection(
        airports: airports,
        cities: [lisbon],
        selection: selectedLisbonAirport,
        zoom: 4,
      );

      final selected = buildSelectedAirportCollection(
        selection: selectedLisbonAirport,
        airports: airports,
      );

      expect(featuresOf(normal), isEmpty);

      expect(featuresOf(selected), hasLength(1));
    });

    test('clearing selection restores airport when zoom allows', () {
      final airports = [lisbonAirport];

      final normal = buildNormalAirportCollection(
        airports: airports,
        cities: [lisbon],
        selection: null,
        zoom: 12,
      );

      final selected = buildSelectedAirportCollection(
        selection: null,
        airports: airports,
      );

      expect(featuresOf(normal).single['id'], 10);

      expect(featuresOf(selected), isEmpty);
    });

    test('clearing selection respects low-zoom collision rules', () {
      final normal = buildNormalAirportCollection(
        airports: [lisbonAirport],
        cities: [lisbon],
        selection: null,
        zoom: 4,
      );

      expect(featuresOf(normal), isEmpty);
    });

    test('normal airport projection remains deterministic', () {
      final first = buildNormalAirportCollection(
        airports: [lisbonAirport, madeiraAirport],
        cities: const [],
        selection: null,
        zoom: 4,
      );

      final second = buildNormalAirportCollection(
        airports: [madeiraAirport, lisbonAirport],
        cities: const [],
        selection: null,
        zoom: 4,
      );

      expect(first, second);
    });
  });
}
