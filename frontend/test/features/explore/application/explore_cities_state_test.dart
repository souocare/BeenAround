import 'package:beenaround/features/explore/application/explore_cities_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreCitiesState', () {
    test('starts with an empty initial state', () {
      const state = ExploreCitiesState();

      expect(state.phase, ExploreCitiesPhase.initial);

      expect(state.isLoading, isFalse);
      expect(state.isReady, isFalse);
      expect(state.hasError, isFalse);
      expect(state.isEmpty, isTrue);

      expect(state.cityCount, 0);
      expect(state.beenCityCount, 0);
      expect(state.livedCityCount, 0);
      expect(state.wishCityCount, 0);

      expect(state.errorMessage, isNull);
    });

    test('exposes loading phase', () {
      const state = ExploreCitiesState(phase: ExploreCitiesPhase.loading);

      expect(state.isLoading, isTrue);
      expect(state.isReady, isFalse);
      expect(state.hasError, isFalse);
    });

    test('exposes ready phase', () {
      const state = ExploreCitiesState(phase: ExploreCitiesPhase.ready);

      expect(state.isLoading, isFalse);
      expect(state.isReady, isTrue);
      expect(state.hasError, isFalse);
    });

    test('exposes failure phase', () {
      const state = ExploreCitiesState(
        phase: ExploreCitiesPhase.failure,
        errorMessage: 'Unable to load Explore cities.',
      );

      expect(state.isLoading, isFalse);
      expect(state.isReady, isFalse);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, isNotNull);
    });
  });
}
