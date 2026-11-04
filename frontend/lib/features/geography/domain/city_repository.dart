import 'city.dart';
import 'city_search_result.dart';
import 'city_sort.dart';
import 'country_city_count.dart';

abstract interface class CityRepository {
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  });

  Future<List<CountryCityCount>> listCountryCityCounts();

  /// Resolves catalog cities by ID in a single API request.
  ///
  /// The result preserves the requested order, removes duplicate IDs,
  /// and omits IDs not found in the catalog.
  ///
  /// The API accepts at most 200 IDs per request.
  Future<List<City>> resolveByIds({required List<int> cityIds});
}
