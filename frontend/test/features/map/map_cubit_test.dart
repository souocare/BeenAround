import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/map/application/map_country_projection.dart';
import 'package:beenaround/features/map/application/map_cubit.dart';
import 'package:beenaround/features/map/application/map_state.dart';
import 'package:beenaround/features/map/domain/map_destination_status.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/map/application/map_city_projection.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';

final _now = DateTime.utc(2026, 11, 18);

CountryVisit makeVisit(String id, String countryCode) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: null,
    endedOn: null,
    createdAt: _now,
    updatedAt: _now,
  );
}

WishlistEntry makeCountryWish(String id, String countryCode) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: null,
    createdAt: _now,
    updatedAt: _now,
  );
}

class FakeCountriesRepository extends Fake implements CountriesRepository {
  List<CountryVisit> visits = [];
  List<Country> countries = [];

  int catalogueLoadCount = 0;

  @override
  Future<List<Country>> getCountries() async {
    catalogueLoadCount++;

    return countries;
  }

  int loadCount = 0;

  Future<List<CountryVisit>> Function()? onLoad;

  @override
  Future<List<CountryVisit>> getCountryVisits() {
    loadCount++;

    if (onLoad != null) {
      return onLoad!();
    }

    return Future.value(visits);
  }
}

class FakeResidencesRepository extends Fake implements ResidenceRepository {
  List<Residence> residences = [];

  int loadCount = 0;

  Future<List<Residence>> Function()? onLoad;

  @override
  Future<List<Residence>> getResidences() {
    loadCount++;

    if (onLoad != null) {
      return onLoad!();
    }

    return Future.value(residences);
  }
}

class FakeWishlistRepository extends Fake implements WishlistRepository {
  List<WishlistEntry> entries = [];

  int loadCount = 0;

  Future<List<WishlistEntry>> Function()? onLoad;

  @override
  Future<List<WishlistEntry>> getWishlistEntries() {
    loadCount++;

    if (onLoad != null) {
      return onLoad!();
    }

    return Future.value(entries);
  }
}

class FakeCityRepository extends Fake implements CityRepository {}

class FakeCityVisitsRepository extends Fake implements CityVisitsRepository {
  List<CityVisit> visits = [];

  int loadCount = 0;

  Future<List<CityVisit>> Function()? onLoad;

  @override
  Future<List<CityVisit>> getCityVisits() {
    loadCount++;

    if (onLoad != null) {
      return onLoad!();
    }

    return Future.value(visits);
  }
}

void main() {
  late FakeCountriesRepository countriesRepository;
  late FakeCityVisitsRepository cityVisitsRepository;
  late FakeResidencesRepository residencesRepository;
  late FakeWishlistRepository wishlistRepository;
  late MapCubit cubit;

  setUp(() {
    countriesRepository = FakeCountriesRepository();
    cityVisitsRepository = FakeCityVisitsRepository();
    residencesRepository = FakeResidencesRepository();
    wishlistRepository = FakeWishlistRepository();

    final cityRepository = FakeCityRepository();

    cubit = MapCubit(
      countriesRepository: countriesRepository,
      cityVisitsRepository: cityVisitsRepository,
      residenceRepository: residencesRepository,
      wishlistRepository: wishlistRepository,
      countryProjection: MapCountryProjection(cityRepository: cityRepository),
      cityProjection: MapCityProjection(cityRepository: cityRepository),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  group('Geographic catalog selection', () {
    test('selects a catalog country using existing country selection', () {
      final destination = MapSearchDestination.country(
        code: 'pt',
        name: 'Portugal',
      );

      cubit.selectSearchDestination(destination);

      expect(cubit.state.selectedCountryCode, 'PT');
      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedSearchDestination, isNull);
    });

    test('selects a city independently of personal travel history', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:123',
        title: 'Tokyo',
        subtitle: 'Japan',
        countryCode: 'JP',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      cubit.selectSearchDestination(destination);

      expect(cubit.state.selectedCityId, 123);
      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedSearchDestination, same(destination));

      // Tokyo does not need to exist in the personal city projection.
      expect(cubit.state.selectedCity, isNull);
    });

    test('selects an airport without modifying country or city data', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:456',
        title: 'Lisbon Airport',
        subtitle: 'LIS · Lisbon, Portugal',
        countryCode: 'PT',
        latitude: 38.7742,
        longitude: -9.1342,
      );

      cubit.selectCountry('ES');

      cubit.selectSearchDestination(destination);

      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedSearchDestination, same(destination));
    });

    test('normal map selection clears temporary catalog selection', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:123',
        title: 'Tokyo',
        subtitle: 'Japan',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      cubit.selectSearchDestination(destination);

      cubit.selectCountry('PT');

      expect(cubit.state.selectedCountryCode, 'PT');
      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedSearchDestination, isNull);
    });

    test('clearing selection also clears a selected airport', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:456',
        title: 'Lisbon Airport',
        subtitle: 'Portugal',
        latitude: 38.7742,
        longitude: -9.1342,
      );

      cubit.selectSearchDestination(destination);

      cubit.clearSelection();

      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedSearchDestination, isNull);
    });

    test('does not select airports without usable coordinates', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:789',
        title: 'Unknown Airport',
        subtitle: 'Unknown location',
      );

      cubit.selectSearchDestination(destination);

      expect(cubit.state.selectedSearchDestination, isNull);
    });

    test('does not emit when selecting the same catalog city again', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.city,
        id: 'city:123',
        title: 'Tokyo',
        subtitle: 'Japan',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      cubit.selectSearchDestination(destination);

      final previousState = cubit.state;

      cubit.selectSearchDestination(destination);

      expect(cubit.state, same(previousState));
    });
  });

  group('MapCubit', () {
    test('starts in initial phase with Visited selected', () {
      expect(cubit.state.phase, MapPhase.initial);
      expect(cubit.state.activeStatus, MapDestinationStatus.visited);
      expect(cubit.state.hasData, isFalse);
    });

    test('loads country visits, residences and wishlist', () async {
      countriesRepository.visits = [
        makeVisit('visit-1', 'PT'),
        makeVisit('visit-2', 'ES'),
        makeVisit('visit-3', 'PT'),
      ];

      wishlistRepository.entries = [makeCountryWish('wish-1', 'JP')];

      await cubit.load();

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.hasData, isTrue);

      expect(cubit.state.countryData!.visitedCountryCodes, {'PT', 'ES'});

      expect(cubit.state.countryData!.livedCountryCodes, isEmpty);

      expect(cubit.state.countryData!.wishlistCountryCodes, {'JP'});

      expect(countriesRepository.loadCount, 1);
      expect(residencesRepository.loadCount, 1);
      expect(wishlistRepository.loadCount, 1);
    });

    test('changes status without reloading repositories', () async {
      countriesRepository.visits = [makeVisit('visit-1', 'PT')];

      wishlistRepository.entries = [makeCountryWish('wish-1', 'JP')];

      await cubit.load();

      expect(cubit.state.highlightedCountryCodes, {'PT'});

      cubit.selectStatus(MapDestinationStatus.wishlist);

      expect(cubit.state.activeStatus, MapDestinationStatus.wishlist);

      expect(cubit.state.highlightedCountryCodes, {'JP'});

      cubit.selectStatus(MapDestinationStatus.lived);

      expect(cubit.state.highlightedCountryCodes, isEmpty);

      expect(countriesRepository.loadCount, 1);
      expect(residencesRepository.loadCount, 1);
      expect(wishlistRepository.loadCount, 1);
    });

    test('preserves previous data when refresh fails', () async {
      countriesRepository.visits = [makeVisit('visit-1', 'PT')];

      await cubit.load();

      final previousData = cubit.state.countryData;

      countriesRepository.onLoad = () async {
        throw StateError('Network unavailable');
      };

      await cubit.refresh();

      expect(cubit.state.phase, MapPhase.failure);
      expect(cubit.state.countryData, same(previousData));
      expect(cubit.state.highlightedCountryCodes, {'PT'});
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('does not publish stale loading results', () async {
      final firstRequest = Completer<List<CountryVisit>>();

      var requestCount = 0;

      countriesRepository.onLoad = () {
        requestCount++;

        if (requestCount == 1) {
          return firstRequest.future;
        }

        return Future.value([makeVisit('new-visit', 'JP')]);
      };

      final firstLoad = cubit.load();

      await cubit.load();

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.highlightedCountryCodes, {'JP'});

      firstRequest.complete([makeVisit('old-visit', 'PT')]);

      await firstLoad;

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.highlightedCountryCodes, {'JP'});
      expect(residencesRepository.loadCount, 1);
      expect(wishlistRepository.loadCount, 1);
    });

    test('does not publish results after closing', () async {
      final request = Completer<List<CountryVisit>>();

      countriesRepository.onLoad = () => request.future;

      final load = cubit.load();

      await cubit.close();

      request.complete([makeVisit('visit-1', 'PT')]);

      await load;

      expect(cubit.isClosed, isTrue);
    });

    test('clears a previous error after successful retry', () async {
      countriesRepository.onLoad = () async {
        throw StateError('Temporary failure');
      };

      await cubit.load();

      expect(cubit.state.phase, MapPhase.failure);
      expect(cubit.state.errorMessage, isNotNull);

      countriesRepository.onLoad = () async => [makeVisit('visit-1', 'ES')];

      await cubit.load();

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.highlightedCountryCodes, {'ES'});
    });
    test('selects a country independently of the active filter', () async {
      await cubit.load();

      cubit.selectCountry('pt');

      expect(cubit.state.selectedCountryCode, 'PT');

      cubit.selectStatus(MapDestinationStatus.wishlist);

      expect(cubit.state.activeStatus, MapDestinationStatus.wishlist);

      expect(cubit.state.selectedCountryCode, 'PT');
    });
    test('replaces the previously selected country', () {
      cubit.selectCountry('PT');

      expect(cubit.state.selectedCountryCode, 'PT');

      cubit.selectCountry('ES');

      expect(cubit.state.selectedCountryCode, 'ES');
    });
    test('clears the selected country', () {
      cubit.selectCountry('PT');

      cubit.clearCountrySelection();

      expect(cubit.state.selectedCountryCode, isNull);
    });
    test('preserves country selection after refreshing data', () async {
      countriesRepository.visits = [makeVisit('visit-1', 'PT')];

      await cubit.load();

      cubit.selectCountry('ES');

      await cubit.refresh();

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.selectedCountryCode, 'ES');
    });
    test('does not emit when selecting the same country again', () {
      cubit.selectCountry('PT');

      final previousState = cubit.state;

      cubit.selectCountry('pt');

      expect(cubit.state, same(previousState));
    });
    test('loads city visits and publishes city projection', () async {
      await cubit.load();

      expect(cubit.state.phase, MapPhase.ready);

      expect(cityVisitsRepository.loadCount, 1);

      expect(cubit.state.cities, isEmpty);

      expect(cubit.state.visibleCities, isEmpty);
    });
    test('preserves previous city data when refresh fails', () async {
      await cubit.load();

      final previousCities = cubit.state.cities;

      cityVisitsRepository.onLoad = () async {
        throw StateError('City visits unavailable');
      };

      await cubit.refresh();

      expect(cubit.state.phase, MapPhase.failure);

      expect(cubit.state.cities, same(previousCities));

      expect(cubit.state.errorMessage, isNotNull);
    });
    test('selects a city independently of the active filter', () {
      cubit.selectCity(123);

      expect(cubit.state.selectedCityId, 123);
      expect(cubit.state.selectedCountryCode, isNull);

      cubit.selectStatus(MapDestinationStatus.wishlist);

      expect(cubit.state.selectedCityId, 123);
    });
    test('selecting a city clears the previous country selection', () {
      cubit.selectCountry('PT');

      expect(cubit.state.selectedCountryCode, 'PT');

      cubit.selectCity(123);

      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedCityId, 123);
    });

    test('selecting a country clears the previous city selection', () {
      cubit.selectCity(123);

      cubit.selectCountry('ES');

      expect(cubit.state.selectedCountryCode, 'ES');
      expect(cubit.state.selectedCityId, isNull);
    });

    test('does not emit when selecting the same city again', () {
      cubit.selectCity(123);

      final previousState = cubit.state;

      cubit.selectCity(123);

      expect(cubit.state, same(previousState));
    });
    test('clears the current geographic selection', () {
      cubit.selectCity(123);

      cubit.clearSelection();

      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedCityId, isNull);
    });
    test('preserves city selection after refreshing data', () async {
      await cubit.load();

      cubit.selectCity(123);

      await cubit.refresh();

      expect(cubit.state.phase, MapPhase.ready);
      expect(cubit.state.selectedCityId, 123);
    });

    test('ignores invalid city identifiers', () {
      final previousState = cubit.state;

      cubit.selectCity(0);
      cubit.selectCity(-1);

      expect(cubit.state, same(previousState));
    });
  });
}
