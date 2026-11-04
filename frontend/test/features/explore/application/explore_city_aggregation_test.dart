import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/application/explore_city_aggregation.dart';
import 'package:beenaround/features/explore/application/visited_cities_state.dart';

import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';

import 'package:beenaround/features/residences/application/residences_state.dart';
import 'package:beenaround/features/residences/domain/residence.dart';

import 'package:beenaround/features/wishlist/application/wishlist_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';

import 'package:flutter_test/flutter_test.dart';

const lisbon = City(
  id: 100,
  name: 'Lisbon',
  asciiName: 'Lisbon',
  countryCode: 'PT',
  countryName: 'Portugal',
  latitude: 38.72,
  longitude: -9.14,
  population: 517802,
  featureCode: 'PPLC',
);

const porto = City(
  id: 102,
  name: 'Porto',
  asciiName: 'Porto',
  countryCode: 'PT',
  countryName: 'Portugal',
  latitude: 41.15,
  longitude: -8.61,
  population: 252687,
  featureCode: 'PPLA',
);

const paris = City(
  id: 104,
  name: 'Paris',
  asciiName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  latitude: 48.86,
  longitude: 2.35,
  population: 2138551,
  featureCode: 'PPLC',
);

final timestamp = DateTime(2026, 11, 4);

CityVisit cityVisit({
  required String id,
  required int cityId,
  String cityName = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
}) {
  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: null,
    endedOn: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Residence residence({
  required String id,
  required String countryCode,
  int? cityId,
}) {
  return Residence(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    startedOn: DateTime(2020, 1),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2022, 12),
    endedOnPrecision: VisitDatePrecision.month,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

WishlistEntry wish({required String id, String? countryCode, int? cityId}) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: cityId,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

VisitedCitiesState visitedState(List<CityVisit> visits) {
  return VisitedCitiesState(phase: VisitedCitiesPhase.ready, visits: visits);
}

ResidencesState residenceState(List<Residence> residences) {
  return ResidencesState(phase: ResidencesPhase.ready, residences: residences);
}

WishlistState wishlistState(List<WishlistEntry> entries) {
  return WishlistState(phase: WishlistPhase.ready, entries: entries);
}

List<ExploreCityEntry> aggregate({
  List<City> cities = const [lisbon, porto, paris],
  List<CityVisit> visits = const [],
  List<Residence> residences = const [],
  List<WishlistEntry> wishlist = const [],
}) {
  return aggregateExploreCities(
    cities: cities,
    visitedCities: visitedState(visits),
    residences: residenceState(residences),
    wishlist: wishlistState(wishlist),
  );
}

ExploreCitySummaryForTest summaryFor(
  List<ExploreCityEntry> entries,
  int cityId,
) {
  final entry = entries.singleWhere((entry) => entry.city.id == cityId);

  return ExploreCitySummaryForTest(entry);
}

class ExploreCitySummaryForTest {
  const ExploreCitySummaryForTest(this.entry);

  final ExploreCityEntry entry;

  int get visitCount => entry.summary.visitCount;
  int get residenceCount => entry.summary.residenceCount;

  bool get hasBeen => entry.summary.hasBeen;
  bool get hasMultipleVisits => entry.summary.hasMultipleVisits;
  bool get hasLived => entry.summary.hasLived;
  bool get isWishlisted => entry.summary.isWishlisted;
  bool get hasAnyStatus => entry.summary.hasAnyStatus;
}

void main() {
  group('Explore city aggregation', () {
    test('returns no destinations when there are no records', () {
      final entries = aggregate();

      expect(entries, isEmpty);
    });

    test('counts explicit city visits', () {
      final entries = aggregate(
        visits: [cityVisit(id: 'visit-1', cityId: 100)],
      );

      final summary = summaryFor(entries, 100);

      expect(summary.visitCount, 1);
      expect(summary.hasBeen, isTrue);
      expect(summary.hasMultipleVisits, isFalse);
      expect(summary.hasLived, isFalse);
      expect(summary.isWishlisted, isFalse);
    });

    test('detects multiple city visits', () {
      final entries = aggregate(
        visits: [
          cityVisit(id: 'visit-1', cityId: 100),
          cityVisit(id: 'visit-2', cityId: 100),
          cityVisit(id: 'visit-3', cityId: 100),
        ],
      );

      final summary = summaryFor(entries, 100);

      expect(summary.visitCount, 3);
      expect(summary.hasMultipleVisits, isTrue);
    });

    test('counts city residences without implying visits', () {
      final entries = aggregate(
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 100),
        ],
      );

      final summary = summaryFor(entries, 100);

      expect(summary.residenceCount, 1);
      expect(summary.hasLived, isTrue);
      expect(summary.hasBeen, isFalse);
    });

    test('country residence does not mark cities as lived', () {
      final entries = aggregate(
        residences: [residence(id: 'residence-1', countryCode: 'PT')],
      );

      expect(entries, isEmpty);
    });

    test('city wishlist requires an explicit city entry', () {
      final entries = aggregate(wishlist: [wish(id: 'wish-1', cityId: 104)]);

      expect(entries, hasLength(1));

      final summary = summaryFor(entries, 104);

      expect(summary.isWishlisted, isTrue);
      expect(summary.hasBeen, isFalse);
      expect(summary.hasLived, isFalse);
    });

    test('country wishlist does not imply city wishlist', () {
      final entries = aggregate(
        wishlist: [wish(id: 'wish-1', countryCode: 'PT')],
      );

      expect(entries, isEmpty);
    });

    test('preserves Been, Lived and Wish simultaneously', () {
      final entries = aggregate(
        visits: [
          cityVisit(id: 'visit-1', cityId: 100),
          cityVisit(id: 'visit-2', cityId: 100),
        ],
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 100),
        ],
        wishlist: [wish(id: 'wish-1', cityId: 100)],
      );

      final summary = summaryFor(entries, 100);

      expect(summary.visitCount, 2);
      expect(summary.residenceCount, 1);

      expect(summary.hasBeen, isTrue);
      expect(summary.hasMultipleVisits, isTrue);
      expect(summary.hasLived, isTrue);
      expect(summary.isWishlisted, isTrue);
      expect(summary.hasAnyStatus, isTrue);
    });

    test('keeps destinations isolated', () {
      final entries = aggregate(
        visits: [cityVisit(id: 'visit-1', cityId: 100)],
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 102),
        ],
        wishlist: [wish(id: 'wish-1', cityId: 104)],
      );

      final lisbonSummary = summaryFor(entries, 100);
      final portoSummary = summaryFor(entries, 102);
      final parisSummary = summaryFor(entries, 104);

      expect(lisbonSummary.hasBeen, isTrue);
      expect(lisbonSummary.hasLived, isFalse);

      expect(portoSummary.hasBeen, isFalse);
      expect(portoSummary.hasLived, isTrue);

      expect(parisSummary.hasBeen, isFalse);
      expect(parisSummary.isWishlisted, isTrue);
    });

    test('does not include unrelated catalog cities', () {
      final entries = aggregate(
        visits: [cityVisit(id: 'visit-1', cityId: 100)],
      );

      expect(entries, hasLength(1));
      expect(entries.single.city.id, 100);
    });

    test('sorts cities by name', () {
      final entries = aggregate(
        wishlist: [
          wish(id: 'wish-1', cityId: 102),
          wish(id: 'wish-2', cityId: 104),
          wish(id: 'wish-3', cityId: 100),
        ],
      );

      expect(entries.map((entry) => entry.city.name).toList(), [
        'Lisbon',
        'Paris',
        'Porto',
      ]);
    });

    test('rejects unresolved referenced cities', () {
      expect(
        () => aggregate(
          cities: const [lisbon],
          wishlist: [wish(id: 'wish-1', cityId: 104)],
        ),
        throwsStateError,
      );
    });

    test('returns an immutable collection', () {
      final entries = aggregate(
        visits: [cityVisit(id: 'visit-1', cityId: 100)],
      );

      expect(() => entries.clear(), throwsUnsupportedError);
    });
  });

  group('Collect Explore city IDs', () {
    test('collects distinct city IDs from all sources', () {
      final ids = collectExploreCityIds(
        visitedCities: visitedState([
          cityVisit(id: 'visit-1', cityId: 100),
          cityVisit(id: 'visit-2', cityId: 100),
        ]),
        residences: residenceState([
          residence(id: 'residence-1', countryCode: 'PT', cityId: 102),
          residence(id: 'residence-2', countryCode: 'PT'),
        ]),
        wishlist: wishlistState([
          wish(id: 'wish-1', cityId: 104),
          wish(id: 'wish-2', countryCode: 'PT'),
        ]),
      );

      expect(ids, [100, 102, 104]);
    });

    test('returns immutable city IDs', () {
      final ids = collectExploreCityIds(
        visitedCities: visitedState([cityVisit(id: 'visit-1', cityId: 100)]),
        residences: residenceState([]),
        wishlist: wishlistState([]),
      );

      expect(() => ids.clear(), throwsUnsupportedError);
    });
  });
}
