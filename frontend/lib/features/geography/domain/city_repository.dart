import 'city_search_result.dart';

abstract interface class CityRepository {
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    int limit = 20,
    int offset = 0,
  });
}
