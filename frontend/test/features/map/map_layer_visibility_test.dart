import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_layer_visibility.dart';
import 'package:beenaround/features/map/application/map_state.dart';

void main() {
  group('MapLayerVisibility', () {
    test('all layers are visible by default', () {
      const visibility = MapLayerVisibility();

      expect(visibility.countries, isTrue);
      expect(visibility.cities, isTrue);
      expect(visibility.airports, isTrue);
      expect(visibility.flightRoutes, isTrue);
    });

    test('copyWith changes only the requested layer', () {
      const visibility = MapLayerVisibility();

      final updated = visibility.copyWith(flightRoutes: false);

      expect(updated.countries, isTrue);
      expect(updated.cities, isTrue);
      expect(updated.airports, isTrue);
      expect(updated.flightRoutes, isFalse);
    });

    test('supports independent visibility combinations', () {
      const visibility = MapLayerVisibility(
        countries: false,
        cities: true,
        airports: false,
        flightRoutes: true,
      );

      expect(visibility.countries, isFalse);
      expect(visibility.cities, isTrue);
      expect(visibility.airports, isFalse);
      expect(visibility.flightRoutes, isTrue);
    });

    test('supports value equality', () {
      const first = MapLayerVisibility(countries: false);

      const second = MapLayerVisibility(countries: false);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('MapState layer visibility', () {
    test('defaults to all visible', () {
      const state = MapState();

      expect(state.layerVisibility, const MapLayerVisibility());
    });

    test('copyWith updates visibility', () {
      const state = MapState();

      final updated = state.copyWith(
        layerVisibility: const MapLayerVisibility(
          cities: false,
          airports: false,
        ),
      );

      expect(updated.layerVisibility.countries, isTrue);
      expect(updated.layerVisibility.cities, isFalse);
      expect(updated.layerVisibility.airports, isFalse);
      expect(updated.layerVisibility.flightRoutes, isTrue);
    });

    test('unrelated state updates preserve visibility', () {
      final state = const MapState().copyWith(
        layerVisibility: const MapLayerVisibility(flightRoutes: false),
      );

      final updated = state.copyWith(selectedCountryCode: 'PT');

      expect(updated.layerVisibility.flightRoutes, isFalse);
      expect(updated.selectedCountryCode, 'PT');
    });
  });
}
