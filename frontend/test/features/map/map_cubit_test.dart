import 'dart:async';
import 'dart:convert';

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
import 'package:beenaround/features/flights/application/flight_catalog_resolver.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

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

class FakeFlightRepository extends Fake implements FlightRepository {
  List<Flight> flights = [];

  int loadCount = 0;

  Future<FlightPage> Function({
    required int limit,
    required int offset,
    FlightStatus? status,
  })?
  onLoad;

  @override
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  }) {
    loadCount++;

    if (onLoad != null) {
      return onLoad!(limit: limit, offset: offset, status: status);
    }

    final filtered = flights
        .where((flight) => status == null || flight.status == status)
        .toList();

    final start = offset.clamp(0, filtered.length);
    final end = (start + limit).clamp(0, filtered.length);

    return Future.value(
      FlightPage(
        items: filtered.sublist(start, end),
        total: filtered.length,
        limit: limit,
        offset: offset,
      ),
    );
  }
}

class FakeAirportRepository extends Fake implements AirportRepository {
  Map<int, Airport> airports = {};

  int loadCount = 0;

  @override
  Future<Airport> getAirport({required int airportId}) async {
    loadCount++;

    final airport = airports[airportId];

    if (airport == null) {
      throw StateError('Airport not found: $airportId');
    }

    return airport;
  }
}

class FakeAirlineRepository extends Fake implements AirlineRepository {}

void main() {
  late FakeCountriesRepository countriesRepository;
  late FakeCityVisitsRepository cityVisitsRepository;
  late FakeResidencesRepository residencesRepository;
  late FakeWishlistRepository wishlistRepository;
  late FakeFlightRepository flightRepository;
  late FakeAirportRepository airportRepository;
  late MapCubit cubit;

  setUp(() {
    countriesRepository = FakeCountriesRepository();
    cityVisitsRepository = FakeCityVisitsRepository();
    residencesRepository = FakeResidencesRepository();
    wishlistRepository = FakeWishlistRepository();
    flightRepository = FakeFlightRepository();
    airportRepository = FakeAirportRepository();

    final cityRepository = FakeCityRepository();
    final flightCatalogResolver = FlightCatalogResolver(
      airportRepository: airportRepository,
      airlineRepository: FakeAirlineRepository(),
    );

    cubit = MapCubit(
      countriesRepository: countriesRepository,
      cityVisitsRepository: cityVisitsRepository,
      residenceRepository: residencesRepository,
      wishlistRepository: wishlistRepository,
      countryProjection: MapCountryProjection(cityRepository: cityRepository),
      cityProjection: MapCityProjection(cityRepository: cityRepository),
      flightRepository: flightRepository,
      flightCatalogResolver: flightCatalogResolver,
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
    test('selects a flight airport without marking its country visited', () {
      const destination = MapSearchDestination(
        type: MapSearchDestinationType.airport,
        id: 'airport:123',
        title: 'Humberto Delgado Airport',
        subtitle: 'LIS',
        countryCode: 'PT',
        latitude: 38.7742,
        longitude: -9.1342,
        airportCode: 'LIS',
      );

      cubit.selectCountry('ES');

      final previousCountryData = cubit.state.countryData;
      final previousCities = cubit.state.cities;
      final previousAirports = cubit.state.airports;

      cubit.selectSearchDestination(destination);

      expect(cubit.state.selectedSearchDestination, same(destination));

      expect(cubit.state.selectedCountryCode, isNull);
      expect(cubit.state.selectedCityId, isNull);

      expect(cubit.state.countryData, same(previousCountryData));
      expect(cubit.state.cities, same(previousCities));
      expect(cubit.state.airports, same(previousAirports));
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
    group('Flight airport loading', () {
      Flight makeFlight({
        required String id,
        required int departureAirportId,
        required int arrivalAirportId,
        FlightStatus status = FlightStatus.flown,
      }) {
        return Flight(
          id: id,
          departureAirportId: departureAirportId,
          arrivalAirportId: arrivalAirportId,
          departureOn: '2026-01-01',
          status: status,
          createdAt: _now,
          updatedAt: _now,
        );
      }

      Airport makeAirport(
        int id,
        String code, {
        double? latitude = 38.7742,
        double? longitude = -9.1342,
        String countryCode = 'PT',
      }) {
        return Airport(
          id: id,
          ident: code,
          iataCode: code,
          name: '$code Airport',
          type: 'large_airport',
          scheduledService: true,
          latitude: latitude,
          longitude: longitude,
          countryCode: countryCode,
        );
      }

      List<dynamic> routeFeatures(MapState state) {
        final geoJson =
            jsonDecode(state.flightRoutesGeoJson) as Map<String, dynamic>;

        expect(geoJson['type'], 'FeatureCollection');

        return geoJson['features'] as List<dynamic>;
      }

      test('loads airports from completed flights', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
          makeFlight(
            id: 'flight-2',
            departureAirportId: 1,
            arrivalAirportId: 3,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'LHR'),
          3: makeAirport(3, 'FNC'),
        };

        await cubit.loadAirports();

        expect(cubit.state.airportPhase, MapAirportPhase.ready);
        expect(cubit.state.airports, hasLength(3));

        expect(cubit.state.airports[1]!.code, 'LIS');
        expect(cubit.state.airports[1]!.departureCount, 2);
        expect(cubit.state.airports[1]!.flightCount, 2);

        expect(airportRepository.loadCount, 3);
      });

      test('loads all pages instead of only the first page', () async {
        flightRepository.flights = List.generate(
          25,
          (index) => makeFlight(
            id: 'flight-$index',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        );

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'LHR'),
        };

        await cubit.loadAirports();

        expect(flightRepository.loadCount, 2);
        expect(cubit.state.airports[1]!.flightCount, 25);
        expect(cubit.state.airports[2]!.flightCount, 25);
      });

      test('excludes planned flights', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'planned',
            departureAirportId: 1,
            arrivalAirportId: 2,
            status: FlightStatus.planned,
          ),
        ];

        await cubit.loadAirports();

        expect(cubit.state.airportPhase, MapAirportPhase.ready);
        expect(cubit.state.airports, isEmpty);
        expect(airportRepository.loadCount, 0);
      });

      test('keeps geographic map available when flights fail', () async {
        flightRepository.onLoad =
            ({
              required int limit,
              required int offset,
              FlightStatus? status,
            }) async {
              throw StateError('Flight API unavailable');
            };

        await cubit.loadAirports();

        expect(cubit.state.airportPhase, MapAirportPhase.failure);
        expect(cubit.state.airports, isEmpty);

        // The independent geographic load state is untouched.
        expect(cubit.state.phase, MapPhase.initial);
        expect(cubit.state.errorMessage, isNull);
      });

      test('preserves the previous airport projection after failure', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'FNC'),
        };

        await cubit.loadAirports();

        final previousAirports = cubit.state.airports;

        flightRepository.onLoad =
            ({
              required int limit,
              required int offset,
              FlightStatus? status,
            }) async {
              throw StateError('Temporary failure');
            };

        await cubit.loadAirports();

        expect(cubit.state.airportPhase, MapAirportPhase.failure);
        expect(cubit.state.airports, same(previousAirports));
        expect(cubit.state.airports, hasLength(2));
      });

      test('refreshes airports after a flight is added', () async {
        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'FNC'),
        };

        await cubit.loadAirports();

        expect(cubit.state.airports, isEmpty);

        flightRepository.flights = [
          makeFlight(
            id: 'new-flight',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        await cubit.loadAirports();

        expect(cubit.state.airports, hasLength(2));
        expect(cubit.state.airports[1]!.flightCount, 1);
      });
      test(
        'loads airport and route projections from one completed flight',
        () async {
          flightRepository.flights = [
            makeFlight(
              id: 'flight-1',
              departureAirportId: 1,
              arrivalAirportId: 2,
            ),
          ];

          airportRepository.airports = {
            1: makeAirport(1, 'LIS'),
            2: makeAirport(
              2,
              'MAD',
              latitude: 40.4983,
              longitude: -3.5676,
              countryCode: 'ES',
            ),
          };

          await cubit.loadAirports();

          final state = cubit.state;

          expect(state.airportPhase, MapAirportPhase.ready);

          // Both airports are represented.
          expect(state.airports, hasLength(2));

          // One unique connection.
          expect(state.flightRoutes, hasLength(1));

          final route = state.flightRoutes.single;

          expect(route.id, '1:2');
          expect(route.flightCount, 1);
          expect(route.flights.single.flightId, 'flight-1');

          // One drawable geographic feature.
          final features = routeFeatures(state);

          expect(features, hasLength(1));

          final feature = features.single as Map<String, dynamic>;

          final properties = feature['properties'] as Map<String, dynamic>;

          expect(properties['route_id'], '1:2');

          final geometry = feature['geometry'] as Map<String, dynamic>;

          expect(geometry['type'], 'MultiLineString');

          // Only one page request and two catalog lookups.
          expect(flightRepository.loadCount, 1);
          expect(airportRepository.loadCount, 2);
        },
      );
      test('aggregates repeated and reverse flights into one route', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
          makeFlight(
            id: 'flight-2',
            departureAirportId: 2,
            arrivalAirportId: 1,
          ),
          makeFlight(
            id: 'flight-3',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        final state = cubit.state;

        expect(state.airports, hasLength(2));
        expect(state.flightRoutes, hasLength(1));

        final route = state.flightRoutes.single;

        expect(route.id, '1:2');
        expect(route.flightCount, 3);

        // Individual flight direction is preserved.
        final reverseFlight = route.flights.singleWhere(
          (flight) => flight.flightId == 'flight-2',
        );

        expect(reverseFlight.departureAirportId, 2);
        expect(reverseFlight.arrivalAirportId, 1);

        // Despite three flights, only one visual feature exists.
        final features = routeFeatures(state);

        expect(features, hasLength(1));

        final properties =
            (features.single as Map<String, dynamic>)['properties']
                as Map<String, dynamic>;

        // Flight frequency must not influence line styling.
        expect(properties.containsKey('flight_count'), isFalse);
      });
      test(
        'preserves route metadata when an airport has no coordinates',
        () async {
          flightRepository.flights = [
            makeFlight(
              id: 'flight-1',
              departureAirportId: 1,
              arrivalAirportId: 2,
            ),
          ];

          airportRepository.airports = {
            1: makeAirport(1, 'LIS'),
            2: makeAirport(2, 'UNK', latitude: null, longitude: null),
          };

          await cubit.loadAirports();

          final state = cubit.state;

          expect(state.airportPhase, MapAirportPhase.ready);

          // Only the airport with valid coordinates can be mapped.
          expect(state.airports, hasLength(1));
          expect(state.airports.containsKey(1), isTrue);
          expect(state.airports.containsKey(2), isFalse);

          // The completed flight still contributes to route metadata.
          expect(state.flightRoutes, hasLength(1));
          expect(state.flightRoutes.single.id, '1:2');
          expect(state.flightRoutes.single.flightCount, 1);

          // The connection cannot be drawn without both coordinates.
          expect(routeFeatures(state), isEmpty);
        },
      );
      test('publishes airports and routes in one ready state', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        final emittedStates = <MapState>[];

        final subscription = cubit.stream.listen(emittedStates.add);

        try {
          await cubit.loadAirports();

          // Allow the Cubit's broadcast stream to deliver emissions.
          await Future<void>.delayed(Duration.zero);

          final flightStates = emittedStates
              .where((state) => state.airportPhase != MapAirportPhase.initial)
              .toList();

          expect(flightStates, hasLength(2));

          final loading = flightStates[0];
          final ready = flightStates[1];

          expect(loading.airportPhase, MapAirportPhase.loading);
          expect(loading.airports, isEmpty);
          expect(loading.flightRoutes, isEmpty);
          expect(routeFeatures(loading), isEmpty);

          expect(ready.airportPhase, MapAirportPhase.ready);
          expect(ready.airports, hasLength(2));
          expect(ready.flightRoutes, hasLength(1));
          expect(routeFeatures(ready), hasLength(1));
        } finally {
          await subscription.cancel();
        }
      });
      test('successful empty refresh clears airports and routes', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        expect(cubit.state.airports, hasLength(2));
        expect(cubit.state.flightRoutes, hasLength(1));
        expect(routeFeatures(cubit.state), hasLength(1));

        // Simulate deletion of all completed personal flights.
        flightRepository.flights = [];

        await cubit.loadAirports();

        expect(cubit.state.airportPhase, MapAirportPhase.ready);

        expect(cubit.state.airports, isEmpty);
        expect(cubit.state.flightRoutes, isEmpty);
        expect(routeFeatures(cubit.state), isEmpty);
      });
      test('ignores stale flight geography loading results', () async {
        final firstRequest = Completer<FlightPage>();
        final secondRequest = Completer<FlightPage>();

        var requestCount = 0;

        flightRepository.onLoad =
            ({required int limit, required int offset, FlightStatus? status}) {
              requestCount++;

              expect(status, FlightStatus.flown);

              if (requestCount == 1) {
                return firstRequest.future;
              }

              if (requestCount == 2) {
                return secondRequest.future;
              }

              throw StateError('Unexpected additional request');
            };

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
          3: makeAirport(3, 'LHR', latitude: 51.4700, longitude: -0.4543),
        };

        // Start an older request.
        final firstLoad = cubit.loadAirports();

        // Start a newer request before the first finishes.
        final secondLoad = cubit.loadAirports();

        expect(requestCount, 2);

        // Complete the newest request first.
        secondRequest.complete(
          FlightPage(
            items: [
              makeFlight(
                id: 'new-flight',
                departureAirportId: 1,
                arrivalAirportId: 3,
              ),
            ],
            total: 1,
            limit: 20,
            offset: 0,
          ),
        );

        await secondLoad;

        expect(cubit.state.airportPhase, MapAirportPhase.ready);
        expect(cubit.state.flightRoutes, hasLength(1));
        expect(cubit.state.flightRoutes.single.id, '1:3');
        expect(routeFeatures(cubit.state), hasLength(1));

        // The older request finishes after the latest state
        // has already been published.
        firstRequest.complete(
          FlightPage(
            items: [
              makeFlight(
                id: 'old-flight',
                departureAirportId: 1,
                arrivalAirportId: 2,
              ),
            ],
            total: 1,
            limit: 20,
            offset: 0,
          ),
        );

        await firstLoad;

        // The stale request must not replace any projection.
        expect(cubit.state.airportPhase, MapAirportPhase.ready);

        expect(cubit.state.airports.containsKey(3), isTrue);
        expect(cubit.state.airports.containsKey(2), isFalse);

        expect(cubit.state.flightRoutes, hasLength(1));
        expect(cubit.state.flightRoutes.single.id, '1:3');

        expect(routeFeatures(cubit.state), hasLength(1));
      });
      test('map filters preserve flight route projections', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        final previousRoutes = cubit.state.flightRoutes;
        final previousGeoJson = cubit.state.flightRoutesGeoJson;
        final previousLoadCount = flightRepository.loadCount;

        cubit.selectStatus(MapDestinationStatus.wishlist);

        expect(cubit.state.flightRoutes, same(previousRoutes));
        expect(cubit.state.flightRoutesGeoJson, previousGeoJson);
        expect(flightRepository.loadCount, previousLoadCount);

        cubit.selectStatus(MapDestinationStatus.lived);

        expect(cubit.state.flightRoutes, same(previousRoutes));
        expect(cubit.state.flightRoutesGeoJson, previousGeoJson);
        expect(flightRepository.loadCount, previousLoadCount);
      });
      test('selects an existing route without modifying flight data', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        final routes = cubit.state.flightRoutes;
        final loadCount = flightRepository.loadCount;

        cubit.selectFlightRoute('1:2');

        expect(cubit.state.selectedFlightRouteId, '1:2');
        expect(cubit.state.selectedFlightRoute?.flightCount, 1);

        expect(cubit.state.selectedCountryCode, isNull);
        expect(cubit.state.selectedCityId, isNull);
        expect(cubit.state.selectedSearchDestination, isNull);

        expect(cubit.state.flightRoutes, same(routes));
        expect(flightRepository.loadCount, loadCount);
      });
      test(
        'ignores selection of a route not present in personal history',
        () async {
          flightRepository.flights = [
            makeFlight(
              id: 'flight-1',
              departureAirportId: 1,
              arrivalAirportId: 2,
            ),
          ];

          airportRepository.airports = {
            1: makeAirport(1, 'LIS'),
            2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
          };

          await cubit.loadAirports();

          cubit.selectCountry('PT');

          cubit.selectFlightRoute('999:999');

          expect(cubit.state.selectedCountryCode, 'PT');
          expect(cubit.state.selectedFlightRouteId, isNull);
        },
      );
      test('selecting a country clears a selected route', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        cubit.selectFlightRoute('1:2');
        expect(cubit.state.selectedFlightRouteId, '1:2');

        cubit.selectCountry('ES');

        expect(cubit.state.selectedCountryCode, 'ES');
        expect(cubit.state.selectedFlightRouteId, isNull);
      });
      test('clearSelection also clears a selected flight route', () async {
        flightRepository.flights = [
          makeFlight(
            id: 'flight-1',
            departureAirportId: 1,
            arrivalAirportId: 2,
          ),
        ];

        airportRepository.airports = {
          1: makeAirport(1, 'LIS'),
          2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
        };

        await cubit.loadAirports();

        cubit.selectFlightRoute('1:2');
        cubit.clearSelection();

        expect(cubit.state.selectedFlightRouteId, isNull);
        expect(cubit.state.flightRoutes, hasLength(1));
      });
      test(
        'clears selected route when successful refresh removes it',
        () async {
          flightRepository.flights = [
            makeFlight(
              id: 'flight-1',
              departureAirportId: 1,
              arrivalAirportId: 2,
            ),
          ];

          airportRepository.airports = {
            1: makeAirport(1, 'LIS'),
            2: makeAirport(2, 'MAD', latitude: 40.4983, longitude: -3.5676),
          };

          await cubit.loadAirports();

          cubit.selectFlightRoute('1:2');

          expect(cubit.state.selectedFlightRouteId, '1:2');

          flightRepository.flights = [];

          await cubit.loadAirports();

          expect(cubit.state.flightRoutes, isEmpty);
          expect(cubit.state.selectedFlightRouteId, isNull);
          expect(cubit.state.airportPhase, MapAirportPhase.ready);
        },
      );
    });
  });
}
