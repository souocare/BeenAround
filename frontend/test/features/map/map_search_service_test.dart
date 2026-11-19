import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';

import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';

import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';

import 'package:beenaround/features/map/application/map_search_service.dart';
import 'package:beenaround/features/map/application/map_search_results.dart';

class FakeCountriesRepository extends Fake implements CountriesRepository {
  int loadCount = 0;
  bool shouldFail = false;

  List<Country> countries = const [];

  @override
  Future<List<Country>> getCountries() async {
    loadCount++;

    if (shouldFail) {
      throw StateError('Countries unavailable');
    }

    return countries;
  }
}

class FakeCityRepository extends Fake implements CityRepository {
  int searchCount = 0;
  bool shouldFail = false;

  String? lastQuery;

  List<City> cities = const [];

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCount++;
    lastQuery = query;

    if (shouldFail) {
      throw StateError('Cities unavailable');
    }

    return CitySearchResult(
      items: cities,
      total: cities.length,
      limit: limit,
      offset: offset,
    );
  }
}

class FakeAirportRepository extends Fake implements AirportRepository {
  int searchCount = 0;
  bool shouldFail = false;

  String? lastQuery;

  List<Airport> airports = const [];

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCount++;
    lastQuery = query;

    if (shouldFail) {
      throw StateError('Airports unavailable');
    }

    return AirportPage(
      items: airports,
      total: airports.length,
      limit: limit,
      offset: offset,
    );
  }
}

void main() {
  late FakeCountriesRepository countriesRepository;
  late FakeCityRepository cityRepository;
  late FakeAirportRepository airportRepository;

  late MapSearchService service;

  setUp(() {
    countriesRepository = FakeCountriesRepository();
    cityRepository = FakeCityRepository();
    airportRepository = FakeAirportRepository();

    service = MapSearchService(
      countriesRepository: countriesRepository,
      cityRepository: cityRepository,
      airportRepository: airportRepository,
    );
  });

  test('empty query does not access repositories', () async {
    final result = await service.search('   ');

    expect(result.hasNoResults, isTrue);

    expect(countriesRepository.loadCount, 0);
    expect(cityRepository.searchCount, 0);
    expect(airportRepository.searchCount, 0);
  });

  test('searches countries by name and ISO code', () async {
    countriesRepository.countries = const [
      Country(
        code: 'PT',
        name: 'Portugal',
        alpha3Code: 'PRT',
        continent: 'Europe',
      ),
      Country(
        code: 'ES',
        name: 'Spain',
        alpha3Code: 'ESP',
        continent: 'Europe',
      ),
    ];

    final byName = await service.search('portugal');

    expect(byName.countries.length, 1);
    expect(byName.countries.first.id, 'country:PT');

    final byCode = await service.search('PT');

    expect(byCode.countries.length, 1);
    expect(byCode.countries.first.id, 'country:PT');

    final byAlpha3 = await service.search('PRT');

    expect(byAlpha3.countries.first.id, 'country:PT');
  });

  test('reuses country catalog across searches', () async {
    countriesRepository.countries = const [
      Country(
        code: 'PT',
        name: 'Portugal',
        alpha3Code: 'PRT',
        continent: 'Europe',
      ),
    ];

    await service.search('Portugal');
    await service.search('Port');
    await service.search('PT');

    expect(countriesRepository.loadCount, 1);
    expect(cityRepository.searchCount, 3);
    expect(airportRepository.searchCount, 3);
  });

  test('normalizes query before calling repositories', () async {
    await service.search('  Lisbon  ');

    expect(cityRepository.lastQuery, 'Lisbon');
    expect(airportRepository.lastQuery, 'Lisbon');
  });

  test('combines city and airport results', () async {
    cityRepository.cities = const [
      City(
        id: 123,
        countryCode: 'PT',
        countryName: 'Portugal',
        name: 'Lisbon',
        asciiName: 'Lisbon',
        latitude: 38.72,
        longitude: -9.14,
        population: 500000,
        featureCode: 'PPLC',
      ),
    ];

    airportRepository.airports = const [
      Airport(
        id: 456,
        ident: 'LPPT',
        name: 'Humberto Delgado Airport',
        type: 'large_airport',
        scheduledService: true,
        iataCode: 'LIS',
        municipality: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        latitude: 38.77,
        longitude: -9.13,
      ),
    ];

    final result = await service.search('Lisbon');

    expect(result.cities.length, 1);
    expect(result.airports.length, 1);

    expect(result.cities.first.id, 'city:123');
    expect(result.airports.first.id, 'airport:456');

    expect(result.hasResults, isTrue);
    expect(result.hasErrors, isFalse);
  });

  test('preserves results when airport search fails', () async {
    cityRepository.cities = const [
      City(
        id: 123,
        countryCode: 'PT',
        countryName: 'Portugal',
        name: 'Lisbon',
        asciiName: 'Lisbon',
        latitude: 38.72,
        longitude: -9.14,
        population: 500000,
        featureCode: 'PPLC',
      ),
    ];

    airportRepository.shouldFail = true;

    final result = await service.search('Lisbon');

    expect(result.cities.length, 1);
    expect(result.airports, isEmpty);

    expect(result.failedCategories, contains(MapSearchCategory.airports));

    expect(result.hasPartialResults, isTrue);
  });

  test('retries country catalog after failure', () async {
    countriesRepository.shouldFail = true;

    final failed = await service.search('Portugal');

    expect(failed.failedCategories, contains(MapSearchCategory.countries));

    countriesRepository.shouldFail = false;

    countriesRepository.countries = const [
      Country(
        code: 'PT',
        name: 'Portugal',
        alpha3Code: 'PRT',
        continent: 'Europe',
      ),
    ];

    final recovered = await service.search('Portugal');

    expect(recovered.countries.length, 1);
    expect(countriesRepository.loadCount, 2);
  });

  test('reports failure when all catalogs fail', () async {
    countriesRepository.shouldFail = true;
    cityRepository.shouldFail = true;
    airportRepository.shouldFail = true;

    final result = await service.search('Lisbon');

    expect(result.allFailed, isTrue);
    expect(result.hasResults, isFalse);
    expect(result.hasNoResults, isFalse);
  });
}
