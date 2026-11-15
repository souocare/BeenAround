import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

class FakeCountriesRepository extends Fake implements CountriesRepository {
  FakeCountriesRepository({List<Country>? countries})
    : countries = List.of(
        countries ??
            const [
              Country(
                code: 'JP',
                name: 'Japan',
                alpha3Code: 'JPN',
                continent: 'AS',
              ),
              Country(
                code: 'PT',
                name: 'Portugal',
                alpha3Code: 'PRT',
                continent: 'EU',
              ),
            ],
      );

  final List<Country> countries;

  int catalogLoadCount = 0;
  final List<CountryVisit> availableVisits = [];

  int countryVisitLoadCount = 0;

  @override
  Future<List<Country>> getCountries() async {
    catalogLoadCount++;

    return List.unmodifiable(countries);
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    countryVisitLoadCount++;

    return List.unmodifiable(availableVisits);
  }

  int createCountryVisitCalls = 0;

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) async {
    createCountryVisitCalls++;

    final visit = CountryVisit(
      id: 'created-country-visit-$createCountryVisitCalls',
      countryCode: countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    availableVisits.add(visit);

    return visit;
  }
}
