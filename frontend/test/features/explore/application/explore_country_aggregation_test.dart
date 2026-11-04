import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/explore/application/explore_country_aggregation.dart';
import 'package:beenaround/features/explore/application/explore_state.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';

import 'package:beenaround/features/residences/application/residences_state.dart';
import 'package:beenaround/features/residences/domain/residence.dart';

import 'package:beenaround/features/wishlist/application/wishlist_state.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';

// -----------------------------------------------------------------------------
// Test fixtures
// -----------------------------------------------------------------------------

const portugal = Country(
  code: 'PT',
  name: 'Portugal',
  alpha3Code: 'PRT',
  continent: 'Europe',
);

const spain = Country(
  code: 'ES',
  name: 'Spain',
  alpha3Code: 'ESP',
  continent: 'Europe',
);

const japan = Country(
  code: 'JP',
  name: 'Japan',
  alpha3Code: 'JPN',
  continent: 'Asia',
);

const france = Country(
  code: 'FR',
  name: 'France',
  alpha3Code: 'FRA',
  continent: 'Europe',
);

final timestamp = DateTime(2026, 11, 3);

CountryVisit countryVisit({required String id, required String countryCode}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: DateTime(2020, 1),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2020, 2),
    endedOnPrecision: VisitDatePrecision.month,
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
    startedOn: DateTime(2020, 3),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2023, 8),
    endedOnPrecision: VisitDatePrecision.month,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

WishlistEntry countryWish({required String id, required String countryCode}) {
  return WishlistEntry(
    id: id,
    countryCode: countryCode,
    cityId: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

WishlistEntry cityWish({required String id, required int cityId}) {
  return WishlistEntry(
    id: id,
    countryCode: null,
    cityId: cityId,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

List<ExploreCountryEntry> aggregate({
  List<CountryVisit> visits = const [],
  List<Residence> residences = const [],
  List<WishlistEntry> wishlist = const [],
}) {
  return aggregateExploreCountries(
    explore: ExploreState(
      phase: ExplorePhase.ready,
      countries: const [portugal, spain, japan, france],
      visits: visits,
    ),
    residences: ResidencesState(
      phase: ResidencesPhase.ready,
      residences: residences,
    ),
    wishlist: WishlistState(phase: WishlistPhase.ready, entries: wishlist),
  );
}

ExploreCountryEntry countryEntry(
  List<ExploreCountryEntry> entries,
  String code,
) {
  return entries.singleWhere((entry) => entry.country.code == code);
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

void main() {
  group('Explore country aggregation', () {
    test('includes the complete country catalogue', () {
      final entries = aggregate();

      expect(entries.length, 4);

      expect(entries.map((entry) => entry.country.code), [
        'PT',
        'ES',
        'JP',
        'FR',
      ]);

      for (final entry in entries) {
        expect(entry.summary.hasAnyStatus, isFalse);
        expect(entry.summary.visitCount, 0);
        expect(entry.summary.totalResidenceCount, 0);
        expect(entry.summary.isWishlisted, isFalse);
      }
    });

    test('counts explicit country visits', () {
      final entries = aggregate(
        visits: [countryVisit(id: 'visit-1', countryCode: 'PT')],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.visitCount, 1);
      expect(summary.hasBeen, isTrue);
      expect(summary.hasMultipleVisits, isFalse);
      expect(summary.hasAnyStatus, isTrue);
    });

    test('detects multiple visits to the same country', () {
      final entries = aggregate(
        visits: [
          countryVisit(id: 'visit-1', countryCode: 'PT'),
          countryVisit(id: 'visit-2', countryCode: 'PT'),
          countryVisit(id: 'visit-3', countryCode: 'PT'),
        ],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.visitCount, 3);
      expect(summary.hasMultipleVisits, isTrue);
    });

    test('counts direct country residences', () {
      final entries = aggregate(
        residences: [residence(id: 'residence-1', countryCode: 'PT')],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.directResidenceCount, 1);
      expect(summary.cityResidenceCount, 0);
      expect(summary.hasDirectResidence, isTrue);
      expect(summary.hasLived, isTrue);

      // Lived must not imply Been.
      expect(summary.hasBeen, isFalse);
    });

    test('derives country lived status from city residences', () {
      final entries = aggregate(
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 2267057),
        ],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.directResidenceCount, 0);
      expect(summary.cityResidenceCount, 1);
      expect(summary.hasCityResidence, isTrue);
      expect(summary.hasLived, isTrue);

      // No country-level residence or visit was created.
      expect(summary.hasDirectResidence, isFalse);
      expect(summary.hasBeen, isFalse);
    });

    test('counts multiple residences independently', () {
      final entries = aggregate(
        residences: [
          residence(id: 'residence-1', countryCode: 'PT'),
          residence(id: 'residence-2', countryCode: 'PT', cityId: 2267057),
          residence(id: 'residence-3', countryCode: 'PT', cityId: 2267057),
        ],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.directResidenceCount, 1);
      expect(summary.cityResidenceCount, 2);
      expect(summary.totalResidenceCount, 3);
    });

    test('country wishlist requires an explicit country entry', () {
      final entries = aggregate(
        wishlist: [countryWish(id: 'wish-1', countryCode: 'JP')],
      );

      expect(countryEntry(entries, 'JP').summary.isWishlisted, isTrue);

      expect(countryEntry(entries, 'PT').summary.isWishlisted, isFalse);
    });

    test('city wishlist does not imply country wishlist', () {
      final entries = aggregate(
        wishlist: [cityWish(id: 'wish-1', cityId: 2267057)],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.isWishlisted, isFalse);
      expect(summary.hasAnyStatus, isFalse);
    });

    test('preserves Been, Lived and Wish simultaneously', () {
      final entries = aggregate(
        visits: [
          countryVisit(id: 'visit-1', countryCode: 'PT'),
          countryVisit(id: 'visit-2', countryCode: 'PT'),
        ],
        residences: [
          residence(id: 'residence-1', countryCode: 'PT', cityId: 2267057),
        ],
        wishlist: [countryWish(id: 'wish-1', countryCode: 'PT')],
      );

      final summary = countryEntry(entries, 'PT').summary;

      expect(summary.visitCount, 2);
      expect(summary.hasBeen, isTrue);
      expect(summary.hasMultipleVisits, isTrue);

      expect(summary.directResidenceCount, 0);
      expect(summary.cityResidenceCount, 1);
      expect(summary.hasLived, isTrue);

      expect(summary.isWishlisted, isTrue);
      expect(summary.hasAnyStatus, isTrue);
    });

    test('keeps statuses isolated between countries', () {
      final entries = aggregate(
        visits: [countryVisit(id: 'visit-1', countryCode: 'PT')],
        residences: [residence(id: 'residence-1', countryCode: 'ES')],
        wishlist: [countryWish(id: 'wish-1', countryCode: 'JP')],
      );

      final pt = countryEntry(entries, 'PT').summary;
      final es = countryEntry(entries, 'ES').summary;
      final jp = countryEntry(entries, 'JP').summary;
      final fr = countryEntry(entries, 'FR').summary;

      expect(pt.hasBeen, isTrue);
      expect(pt.hasLived, isFalse);
      expect(pt.isWishlisted, isFalse);

      expect(es.hasBeen, isFalse);
      expect(es.hasLived, isTrue);
      expect(es.isWishlisted, isFalse);

      expect(jp.hasBeen, isFalse);
      expect(jp.hasLived, isFalse);
      expect(jp.isWishlisted, isTrue);

      expect(fr.hasAnyStatus, isFalse);
    });

    test('returns an immutable collection', () {
      final entries = aggregate();

      expect(() => entries.clear(), throwsUnsupportedError);
    });
  });
}
