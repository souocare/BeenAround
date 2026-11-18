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

void main() {
  late FakeCountriesRepository countriesRepository;
  late FakeResidencesRepository residencesRepository;
  late FakeWishlistRepository wishlistRepository;
  late MapCubit cubit;

  setUp(() {
    countriesRepository = FakeCountriesRepository();
    residencesRepository = FakeResidencesRepository();
    wishlistRepository = FakeWishlistRepository();

    cubit = MapCubit(
      countriesRepository: countriesRepository,
      residenceRepository: residencesRepository,
      wishlistRepository: wishlistRepository,
      countryProjection: MapCountryProjection(
        cityRepository: FakeCityRepository(),
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
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
  });
}
