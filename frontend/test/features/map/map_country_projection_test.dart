import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:beenaround/features/map/application/map_country_projection.dart';
import 'package:beenaround/features/map/domain/map_destination_status.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

class FakeMapCityRepository implements CityRepository {
  FakeMapCityRepository(this.cities);

  final Map<int, City> cities;

  final List<List<int>> requestedBatches = [];

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    requestedBatches.add(List.of(cityIds));

    return [
      for (final id in cityIds)
        if (cities[id] case final City city) city,
    ];
  }

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() {
    throw UnimplementedError();
  }
}

final _now = DateTime.utc(2026, 11, 16);

CountryVisit visit(String id, String countryCode) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: null,
    endedOn: null,
    createdAt: _now,
    updatedAt: _now,
  );
}

Residence residence(String id, String countryCode, {int? cityId}) {
  return Residence(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    startedOn: DateTime.utc(2020),
    startedOnPrecision: VisitDatePrecision.year,
    endedOn: DateTime.utc(2021),
    endedOnPrecision: VisitDatePrecision.year,
    createdAt: _now,
    updatedAt: _now,
  );
}

WishlistEntry countryWish(String id, String countryCode) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: null,
    createdAt: _now,
    updatedAt: _now,
  );
}

WishlistEntry cityWish(String id, int cityId) {
  return WishlistEntry(
    id: id,
    countryCode: null,
    cityId: cityId,
    createdAt: _now,
    updatedAt: _now,
  );
}

City city(int id, String countryCode, {String name = 'Test City'}) {
  return City(
    id: id,
    countryCode: countryCode,
    countryName: 'Test Country',
    name: name,
    asciiName: name,
    latitude: 0,
    longitude: 0,
    population: null,
    featureCode: 'PPL',
  );
}

void main() {
  group('MapCountryProjection', () {
    test('deduplicates multiple visits to the same country', () async {
      final projection = MapCountryProjection(
        cityRepository: FakeMapCityRepository({}),
      );

      final result = await projection.build(
        visits: [
          visit('visit-1', 'PT'),
          visit('visit-2', 'PT'),
          visit('visit-3', 'ES'),
        ],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.visitedCountryCodes, {'PT', 'ES'});
    });

    test('includes city residences in their country', () async {
      final projection = MapCountryProjection(
        cityRepository: FakeMapCityRepository({}),
      );

      final result = await projection.build(
        visits: [],
        residences: [
          residence('residence-1', 'PT', cityId: 100),
          residence('residence-2', 'ES'),
        ],
        wishlistEntries: [],
      );

      expect(result.livedCountryCodes, {'PT', 'ES'});
      expect(result.visitedCountryCodes, isEmpty);
    });

    test('resolves wishlist cities to their countries', () async {
      final repository = FakeMapCityRepository({
        10: city(10, 'ES', name: 'Barcelona'),
        20: city(20, 'JP', name: 'Tokyo'),
      });

      final projection = MapCountryProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [],
        wishlistEntries: [
          countryWish('wish-1', 'PT'),
          cityWish('wish-2', 10),
          cityWish('wish-3', 20),
        ],
      );

      expect(result.wishlistCountryCodes, {'PT', 'ES', 'JP'});
      expect(result.cityWishlistCountryCodes, {'ES', 'JP'});
      expect(repository.requestedBatches, [
        [10, 20],
      ]);
    });

    test('allows the same country in all three categories', () async {
      final projection = MapCountryProjection(
        cityRepository: FakeMapCityRepository({}),
      );

      final result = await projection.build(
        visits: [visit('visit-1', 'PT')],
        residences: [residence('residence-1', 'PT')],
        wishlistEntries: [countryWish('wish-1', 'PT')],
      );

      expect(result.countriesFor(MapDestinationStatus.visited), {'PT'});

      expect(result.countriesFor(MapDestinationStatus.lived), {'PT'});

      expect(result.countriesFor(MapDestinationStatus.wishlist), {'PT'});
    });

    test('returns empty sets when no records exist', () async {
      final repository = FakeMapCityRepository({});

      final projection = MapCountryProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.visitedCountryCodes, isEmpty);
      expect(result.livedCountryCodes, isEmpty);
      expect(result.wishlistCountryCodes, isEmpty);

      expect(repository.requestedBatches, isEmpty);
    });

    test('batches city resolution at the 200 ID API limit', () async {
      final repository = FakeMapCityRepository({
        for (var id = 1; id <= 205; id++) id: city(id, id.isEven ? 'PT' : 'ES'),
      });

      final projection = MapCountryProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [],
        wishlistEntries: [
          for (var id = 1; id <= 205; id++) cityWish('wish-$id', id),
        ],
      );

      expect(repository.requestedBatches.length, 2);
      expect(repository.requestedBatches[0].length, 200);
      expect(repository.requestedBatches[1].length, 5);

      expect(result.wishlistCountryCodes, {'PT', 'ES'});
    });

    test('returns immutable country sets', () async {
      final projection = MapCountryProjection(
        cityRepository: FakeMapCityRepository({}),
      );

      final result = await projection.build(
        visits: [visit('visit-1', 'PT')],
        residences: [],
        wishlistEntries: [],
      );

      expect(
        () => result.visitedCountryCodes.add('ES'),
        throwsUnsupportedError,
      );
    });
    test('does not invent countries for unresolved wishlist cities', () async {
      final repository = FakeMapCityRepository({
        10: city(10, 'ES', name: 'Barcelona'),
      });

      final projection = MapCountryProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [],
        wishlistEntries: [cityWish('wish-1', 10), cityWish('wish-2', 999)],
      );

      expect(result.wishlistCountryCodes, {'ES'});
      expect(repository.requestedBatches, [
        [10, 999],
      ]);
    });
    test('preserves direct and city wishlist membership together', () async {
      final repository = FakeMapCityRepository({
        10: city(10, 'ES', name: 'Barcelona'),
      });

      final projection = MapCountryProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [],
        wishlistEntries: [
          countryWish('wish-country', 'ES'),
          cityWish('wish-city', 10),
        ],
      );

      expect(result.wishlistCountryCodes, {'ES'});
      expect(result.cityWishlistCountryCodes, {'ES'});

      expect(repository.requestedBatches, [
        [10],
      ]);
    });
  });
}
