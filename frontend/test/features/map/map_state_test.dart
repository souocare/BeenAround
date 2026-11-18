import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_state.dart';
import 'package:beenaround/features/map/domain/map_country_data.dart';
import 'package:beenaround/features/map/domain/map_destination_status.dart';

void main() {
  group('MapState', () {
    test('starts with Visited selected', () {
      const state = MapState();

      expect(state.phase, MapPhase.initial);
      expect(state.activeStatus, MapDestinationStatus.visited);
      expect(state.countryData, isNull);
      expect(state.hasData, isFalse);
      expect(state.highlightedCountryCodes, isEmpty);
    });

    test('returns countries for the active status', () {
      final data = MapCountryData(
        visitedCountryCodes: {'PT', 'ES'},
        livedCountryCodes: {'PT'},
        wishlistCountryCodes: {'JP', 'IS'},
      );

      final state = MapState(phase: MapPhase.ready, countryData: data);

      expect(state.highlightedCountryCodes, {'PT', 'ES'});

      final livedState = state.copyWith(
        activeStatus: MapDestinationStatus.lived,
      );

      expect(livedState.highlightedCountryCodes, {'PT'});

      final wishlistState = state.copyWith(
        activeStatus: MapDestinationStatus.wishlist,
      );

      expect(wishlistState.highlightedCountryCodes, {'JP', 'IS'});
    });

    test('distinguishes loaded empty data from missing data', () {
      const initial = MapState();

      final loaded = MapState(
        phase: MapPhase.ready,
        countryData: MapCountryData(
          visitedCountryCodes: {},
          livedCountryCodes: {},
          wishlistCountryCodes: {},
        ),
      );

      expect(initial.hasData, isFalse);
      expect(loaded.hasData, isTrue);
      expect(loaded.highlightedCountryCodes, isEmpty);
    });

    test('preserves the last valid projection during refresh', () {
      final data = MapCountryData(
        visitedCountryCodes: {'PT'},
        livedCountryCodes: {},
        wishlistCountryCodes: {},
      );

      final ready = MapState(phase: MapPhase.ready, countryData: data);

      final loading = ready.copyWith(phase: MapPhase.loading);

      expect(loading.phase, MapPhase.loading);
      expect(loading.countryData, same(data));
      expect(loading.highlightedCountryCodes, {'PT'});
    });

    test('clears stale errors without discarding data', () {
      final data = MapCountryData(
        visitedCountryCodes: {'PT'},
        livedCountryCodes: {},
        wishlistCountryCodes: {},
      );

      final failed = MapState(
        phase: MapPhase.failure,
        countryData: data,
        errorMessage: 'Network error',
      );

      final loading = failed.copyWith(
        phase: MapPhase.loading,
        clearError: true,
      );

      expect(loading.errorMessage, isNull);
      expect(loading.countryData, same(data));
    });
    test('returns null preview when no country is selected', () {
      const state = MapState();

      expect(state.selectedCountryPreview, isNull);
    });

    test('returns null preview for unknown country code', () {
      const state = MapState(selectedCountryCode: 'XX');

      expect(state.selectedCountryPreview, isNull);
    });
  });
}
