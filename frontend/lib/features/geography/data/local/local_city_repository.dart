import '../../domain/city.dart';
import '../../domain/city_repository.dart';
import '../../domain/city_search_result.dart';
import 'geography_database.dart';

class LocalCityRepository implements CityRepository {
  const LocalCityRepository({required this.database});

  final GeographyDatabase database;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
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
    String orderClause;

    if (escapedQuery != null) {
      orderClause = r'''
        CASE
          WHEN LOWER(cities.name) = LOWER(?)
            OR LOWER(cities.ascii_name) = LOWER(?)
          THEN 0

          WHEN cities.name LIKE ? ESCAPE '\'
            OR cities.ascii_name LIKE ? ESCAPE '\'
          THEN 1

          ELSE 2
        END,
        cities.population DESC NULLS LAST,
        cities.name,
        cities.id
      ''';

      orderArguments.addAll([
        normalizedQuery,
        normalizedQuery,
        '$escapedQuery%',
        '$escapedQuery%',
      ]);
    } else {
      orderClause = '''
        cities.population DESC NULLS LAST,
        cities.name,
        cities.id
      ''';
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
