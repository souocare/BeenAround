import '../../domain/city.dart';
import '../../domain/city_repository.dart';
import '../../domain/city_search_result.dart';
import 'geography_database.dart';
import '../../domain/city_sort.dart';
import '../../domain/country_city_count.dart';

class LocalCityRepository implements CityRepository {
  const LocalCityRepository({required this.database});

  final GeographyDatabase database;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    CitySort sort = CitySort.population,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedQuery = query?.trim();
    final normalizedCountryCode = countryCode?.trim().toUpperCase();

    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }

    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset');
    }

    if ((normalizedQuery == null || normalizedQuery.isEmpty) &&
        (normalizedCountryCode == null || normalizedCountryCode.isEmpty)) {
      throw ArgumentError('A query or country code must be provided.');
    }

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (normalizedCountryCode != null && normalizedCountryCode.isNotEmpty) {
      conditions.add('cities.country_code = ?');
      arguments.add(normalizedCountryCode);
    }

    String? escapedQuery;

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      escapedQuery = normalizedQuery
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');

      final pattern = '%$escapedQuery%';

      conditions.add(
        r"(cities.name LIKE ? ESCAPE '\' COLLATE NOCASE "
        r"OR cities.ascii_name LIKE ? ESCAPE '\' COLLATE NOCASE)",
      );

      arguments.addAll([pattern, pattern]);
    }

    final whereClause = conditions.join(' AND ');

    final countResult = await database.select('''
      SELECT COUNT(*) AS total
      FROM cities
      WHERE $whereClause
      ''', arguments);

    final total = countResult.single['total'] as int;

    final orderArguments = <Object?>[];

    final sortClause = switch (sort) {
      CitySort.population =>
        '''
    cities.population DESC NULLS LAST,
    LOWER(cities.name),
    cities.name,
    cities.id
  ''',
      CitySort.name =>
        '''
    LOWER(cities.name),
    cities.name,
    cities.id
  ''',
    };

    String orderClause;

    if (escapedQuery != null) {
      orderClause =
          r'''
    CASE
      WHEN LOWER(cities.name) = LOWER(?)
        OR LOWER(cities.ascii_name) = LOWER(?)
      THEN 0

      WHEN cities.name LIKE ? ESCAPE '\'
        OR cities.ascii_name LIKE ? ESCAPE '\'
      THEN 1

      ELSE 2
    END,
  ''' +
          sortClause;

      orderArguments.addAll([
        normalizedQuery,
        normalizedQuery,
        '$escapedQuery%',
        '$escapedQuery%',
      ]);
    } else {
      orderClause = sortClause;
    }

    final rows = await database.select(
      '''
      SELECT
        cities.id,
        cities.name,
        cities.ascii_name,
        cities.country_code,
        countries.name AS country_name,
        cities.latitude,
        cities.longitude,
        cities.population,
        cities.feature_code
      FROM cities
      JOIN countries
        ON countries.code = cities.country_code
      WHERE $whereClause
      ORDER BY $orderClause
      LIMIT ? OFFSET ?
      ''',
      [...arguments, ...orderArguments, limit, offset],
    );

    return CitySearchResult(
      items: rows.map(_mapCity).toList(growable: false),
      total: total,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    final rows = await database.select('''
    SELECT
      countries.code AS country_code,
      countries.name AS country_name,
      COUNT(cities.id) AS city_count
    FROM countries
    LEFT JOIN cities
      ON cities.country_code = countries.code
    GROUP BY countries.code, countries.name
    ORDER BY countries.name, countries.code
  ''', []);

    return rows
        .map(
          (row) => CountryCityCount(
            countryCode: row['country_code'] as String,
            countryName: row['country_name'] as String,
            cityCount: row['city_count'] as int,
          ),
        )
        .toList(growable: false);
  }

  City _mapCity(Map<String, Object?> row) {
    return City(
      id: row['id'] as int,
      name: row['name'] as String,
      asciiName: row['ascii_name'] as String?,
      countryCode: row['country_code'] as String,
      countryName: row['country_name'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      population: row['population'] as int?,
      featureCode: row['feature_code'] as String,
    );
  }
}
