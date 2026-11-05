import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';

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
}
