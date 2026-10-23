import 'city.dart';

class CitySearchResult {
  const CitySearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<City> items;
  final int total;
  final int limit;
  final int offset;
}
