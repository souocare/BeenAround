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
}
