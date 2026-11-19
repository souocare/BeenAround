import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/map/application/map_city_projection.dart';
import 'package:beenaround/features/map/domain/map_destination_status.dart';
import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';

class _FakeCityRepository implements CityRepository {
  _FakeCityRepository(this.cities);

  final Map<int, City> cities;

  final List<List<int>> requestedBatches = [];

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    requestedBatches.add(List<int>.from(cityIds));

    return [
      for (final id in cityIds)
        if (cities[id] case final City city) city,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

City _city({
  required int id,
  required String name,
  required String countryCode,
  double latitude = 38.72,
  double longitude = -9.14,
}) {
  return City(
    id: id,
    name: name,
    asciiName: name,
    countryCode: countryCode,
    countryName: countryCode,
    latitude: latitude,
    longitude: longitude,
    population: null,
    featureCode: 'PPL',
  );
}

CityVisit _visit({required String id, required int cityId}) {
  final now = DateTime.utc(2026, 1, 1);

  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: 'Test City',
    countryCode: 'PT',
    countryName: 'Portugal',
    startedOn: null,
    endedOn: null,
    createdAt: now,
    updatedAt: now,
  );
}

Residence _residence({required String id, int? cityId}) {
  final now = DateTime.utc(2026, 1, 1);

  return Residence(
    id: id,
    countryCode: 'PT',
    cityId: cityId,
    startedOn: now,
    startedOnPrecision: VisitDatePrecision.day,
    endedOn: now,
    endedOnPrecision: VisitDatePrecision.day,
    createdAt: now,
    updatedAt: now,
  );
}

WishlistEntry _wishlist({
  required String id,
  int? cityId,
  String? countryCode,
}) {
  final now = DateTime.utc(2026, 1, 1);

  return WishlistEntry(
    id: id,
    cityId: cityId,
    countryCode: countryCode,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('MapCityProjection', () {
    test('groups multiple visits into one city marker', () async {
      final repository = _FakeCityRepository({
        1: _city(id: 1, name: 'Lisbon', countryCode: 'PT'),
      });

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [
          _visit(id: 'visit-1', cityId: 1),
          _visit(id: 'visit-2', cityId: 1),
          _visit(id: 'visit-3', cityId: 1),
        ],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.length, 1);
      expect(result[1]?.visitCount, 3);
      expect(result[1]?.isVisited, isTrue);
      expect(result[1]?.isLived, isFalse);
      expect(result[1]?.isWishlisted, isFalse);

      expect(repository.requestedBatches, [
        [1],
      ]);
    });

    test('combines independent destination statuses', () async {
      final repository = _FakeCityRepository({
        1: _city(id: 1, name: 'Lisbon', countryCode: 'PT'),
      });

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [_visit(id: 'visit-1', cityId: 1)],
        residences: [_residence(id: 'residence-1', cityId: 1)],
        wishlistEntries: [_wishlist(id: 'wishlist-1', cityId: 1)],
      );

      final city = result[1]!;

      expect(city.isVisited, isTrue);
      expect(city.isLived, isTrue);
      expect(city.isWishlisted, isTrue);

      expect(city.matchesStatus(MapDestinationStatus.visited), isTrue);

      expect(city.matchesStatus(MapDestinationStatus.lived), isTrue);

      expect(city.matchesStatus(MapDestinationStatus.wishlist), isTrue);
    });

    test('does not create cities from country-only records', () async {
      final repository = _FakeCityRepository({});

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [],
        residences: [_residence(id: 'residence-1')],
        wishlistEntries: [_wishlist(id: 'wishlist-1', countryCode: 'PT')],
      );

      expect(result, isEmpty);
      expect(repository.requestedBatches, isEmpty);
    });

    test('distinguishes cities by catalog ID', () async {
      final repository = _FakeCityRepository({
        1: _city(id: 1, name: 'Springfield', countryCode: 'US'),
        2: _city(id: 2, name: 'Springfield', countryCode: 'CA'),
      });

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [
          _visit(id: 'visit-1', cityId: 1),
          _visit(id: 'visit-2', cityId: 2),
        ],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.length, 2);
      expect(result[1]?.countryCode, 'US');
      expect(result[2]?.countryCode, 'CA');
    });

    test('ignores missing catalog cities', () async {
      final repository = _FakeCityRepository({});

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [_visit(id: 'visit-1', cityId: 999)],
        residences: [],
        wishlistEntries: [],
      );

      expect(result, isEmpty);
    });

    test('ignores invalid geographic coordinates', () async {
      final repository = _FakeCityRepository({
        1: _city(id: 1, name: 'Invalid City', countryCode: 'PT', latitude: 120),
        2: _city(id: 2, name: 'Valid City', countryCode: 'PT'),
      });

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [
          _visit(id: 'visit-1', cityId: 1),
          _visit(id: 'visit-2', cityId: 2),
        ],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.containsKey(1), isFalse);
      expect(result.containsKey(2), isTrue);
    });

    test('splits catalog resolution into batches of 200', () async {
      final cities = {
        for (var id = 1; id <= 205; id++)
          id: _city(id: id, name: 'City $id', countryCode: 'PT'),
      };

      final repository = _FakeCityRepository(cities);

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [
          for (var id = 1; id <= 205; id++) _visit(id: 'visit-$id', cityId: id),
        ],
        residences: [],
        wishlistEntries: [],
      );

      expect(result.length, 205);

      expect(repository.requestedBatches.map((batch) => batch.length), [
        200,
        5,
      ]);
    });

    test('returns an immutable projection', () async {
      final repository = _FakeCityRepository({
        1: _city(id: 1, name: 'Lisbon', countryCode: 'PT'),
      });

      final projection = MapCityProjection(cityRepository: repository);

      final result = await projection.build(
        visits: [_visit(id: 'visit-1', cityId: 1)],
        residences: [],
        wishlistEntries: [],
      );

      expect(() => result.clear(), throwsUnsupportedError);
    });
  });
}
