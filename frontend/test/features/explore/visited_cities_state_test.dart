import 'package:beenaround/features/explore/application/visited_cities_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:flutter_test/flutter_test.dart';

CityVisit makeVisit({
  required String id,
  required int cityId,
  required String cityName,
  required String countryCode,
  required String countryName,
}) {
  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 24),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  test('initial state has no visited cities', () {
    const state = VisitedCitiesState();

    expect(state.phase, VisitedCitiesPhase.initial);
    expect(state.totalVisits, 0);
    expect(state.visitedCityCount, 0);
    expect(state.visitedCities, isEmpty);
  });

  test('groups multiple visits by city ID', () {
    final state = VisitedCitiesState(
      phase: VisitedCitiesPhase.ready,
      visits: [
        makeVisit(
          id: '1',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
        makeVisit(
          id: '2',
          cityId: 3117735,
          cityName: 'Madrid',
          countryCode: 'ES',
          countryName: 'Spain',
        ),
        makeVisit(
          id: '3',
          cityId: 2267057,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    expect(state.totalVisits, 3);
    expect(state.visitedCityCount, 2);

    final lisbon = state.visitedCities.firstWhere(
      (city) => city.cityId == 2267057,
    );

    expect(lisbon.visitCount, 2);
    expect(lisbon.countryName, 'Portugal');
    expect(state.visitsForCity(2267057), hasLength(2));
  });

  test('does not merge different cities with the same name', () {
    final state = VisitedCitiesState(
      phase: VisitedCitiesPhase.ready,
      visits: [
        makeVisit(
          id: '1',
          cityId: 100,
          cityName: 'Springfield',
          countryCode: 'US',
          countryName: 'United States',
        ),
        makeVisit(
          id: '2',
          cityId: 200,
          cityName: 'Springfield',
          countryCode: 'US',
          countryName: 'United States',
        ),
      ],
    );

    expect(state.visitedCityCount, 2);
  });

  test('sorts visited cities alphabetically', () {
    final state = VisitedCitiesState(
      phase: VisitedCitiesPhase.ready,
      visits: [
        makeVisit(
          id: '1',
          cityId: 1,
          cityName: 'Zurich',
          countryCode: 'CH',
          countryName: 'Switzerland',
        ),
        makeVisit(
          id: '2',
          cityId: 2,
          cityName: 'Amsterdam',
          countryCode: 'NL',
          countryName: 'Netherlands',
        ),
        makeVisit(
          id: '3',
          cityId: 3,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    expect(state.visitedCities.map((city) => city.cityName).toList(), [
      'Amsterdam',
      'Lisbon',
      'Zurich',
    ]);
  });

  test('returns an empty list for a city without visits', () {
    const state = VisitedCitiesState();

    expect(state.visitsForCity(999), isEmpty);
  });

  test('exposes unmodifiable grouped visits', () {
    final state = VisitedCitiesState(
      phase: VisitedCitiesPhase.ready,
      visits: [
        makeVisit(
          id: '1',
          cityId: 1,
          cityName: 'Lisbon',
          countryCode: 'PT',
          countryName: 'Portugal',
        ),
      ],
    );

    expect(() => state.visitedCities.clear(), throwsUnsupportedError);

    expect(
      () => state.visitedCities.first.visits.clear(),
      throwsUnsupportedError,
    );
  });
}
