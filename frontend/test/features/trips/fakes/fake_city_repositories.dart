import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/geography/domain/city.dart';
import 'package:beenaround/features/geography/domain/city_repository.dart';
import 'package:beenaround/features/geography/domain/city_search_result.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_city_count.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';

class FakeCityRepository implements CityRepository {
  int searchCalls = 0;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    int limit = 20,
    int offset = 0,
    CitySort sort = CitySort.population,
  }) async {
    searchCalls++;

    const cities = [
      City(
        id: 2267057,
        name: 'Lisbon',
        asciiName: 'Lisbon',
        countryCode: 'PT',
        countryName: 'Portugal',
        latitude: 38.7167,
        longitude: -9.1333,
        population: 517802,
        featureCode: 'PPLC',
      ),
      City(
        id: 3117735,
        name: 'Madrid',
        asciiName: 'Madrid',
        countryCode: 'ES',
        countryName: 'Spain',
        latitude: 40.4165,
        longitude: -3.7026,
        population: 3255944,
        featureCode: 'PPLC',
      ),
    ];

    final normalizedQuery = query?.trim().toLowerCase() ?? '';

    final matches = cities
        .where((city) {
          final matchesName =
              normalizedQuery.isEmpty ||
              city.name.toLowerCase().contains(normalizedQuery);

          final matchesCountry =
              countryCode == null ||
              city.countryCode == countryCode.toUpperCase();

          return matchesName && matchesCountry;
        })
        .toList(growable: false);

    return CitySearchResult(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) {
    throw UnimplementedError();
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    return const [
      CountryCityCount(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityCount: 1,
      ),
      CountryCityCount(countryCode: 'ES', countryName: 'Spain', cityCount: 1),
    ];
  }
}

class FakeCityVisitsRepository implements CityVisitsRepository {
  int createCalls = 0;
  int? lastCreatedCityId;

  DateTime? lastStartedOn;
  DateTime? lastEndedOn;
  String? lastCountryVisitId;
  NewCountryVisitInput? lastNewCountryVisit;
  CountryVisitDateExpansion? lastCountryDateExpansion;

  VisitDatePrecision? lastStartedOnPrecision;
  VisitDatePrecision? lastEndedOnPrecision;
  CountryVisitDateExpansion? expansionOnFirstCreate;

  final List<CityVisit> createdVisits = [];

  @override
  Future<List<CityVisit>> getCityVisits() async {
    return List.unmodifiable(createdVisits);
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    createCalls++;

    lastCreatedCityId = cityId;

    lastStartedOn = startedOn;
    lastEndedOn = endedOn;

    lastStartedOnPrecision = startedOnPrecision;
    lastEndedOnPrecision = endedOnPrecision;

    lastCountryVisitId = countryVisitId;
    lastNewCountryVisit = newCountryVisit;
    lastCountryDateExpansion = countryDateExpansion;
    // Simulate a backend proposal on the first request only.
    // No city visit is persisted until confirmation succeeds.
    if (createCalls == 1 && expansionOnFirstCreate != null) {
      throw CountryVisitDateExpansionRequired(expansionOnFirstCreate!);
    }

    final visit = CityVisit(
      id: 'city-visit-$createCalls',
      cityId: cityId,
      cityName: cityId == 2267057 ? 'Lisbon' : 'Madrid',
      countryCode: cityId == 2267057 ? 'PT' : 'ES',
      countryName: cityId == 2267057 ? 'Portugal' : 'Spain',
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      createdAt: DateTime(2026, 10, 24),
      updatedAt: DateTime(2026, 10, 24),
      countryVisitId: countryVisitId,
    );

    createdVisits.add(visit);

    return visit;
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}
