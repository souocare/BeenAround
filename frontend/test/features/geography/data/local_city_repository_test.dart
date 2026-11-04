import 'dart:io';

import 'package:beenaround/features/geography/data/local/geography_database.dart';
import 'package:beenaround/features/geography/data/local/local_city_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late Directory directory;
  late GeographyDatabase geographyDatabase;
  late LocalCityRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'beenaround_geography_test_',
    );

    final databaseFile = File('${directory.path}/test.sqlite');

    // Create a small SQLite catalog for isolated repository tests.
    final connection = sqlite3.sqlite3.open(databaseFile.path);

    try {
      connection.execute('''
        CREATE TABLE countries (
          code TEXT PRIMARY KEY,
          name TEXT NOT NULL
        );

        CREATE TABLE cities (
          id INTEGER PRIMARY KEY,
          country_code TEXT NOT NULL,
          name TEXT NOT NULL,
          ascii_name TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          population INTEGER,
          feature_code TEXT NOT NULL
        );

        INSERT INTO countries VALUES ('PT', 'Portugal');
        INSERT INTO countries VALUES ('BR', 'Brazil');
        INSERT INTO countries VALUES ('FR', 'France');

        INSERT INTO cities VALUES
          (1, 'PT', 'Lisbon', 'Lisbon', 38.72, -9.13, 500000, 'PPLC'),
          (2, 'PT', 'Porto', 'Porto', 41.15, -8.61, 250000, 'PPLA'),
          (3, 'BR', 'São Paulo', 'Sao Paulo', -23.55, -46.63, 12000000, 'PPLA'),
          (4, 'FR', 'Paris', 'Paris', 48.85, 2.35, 2100000, 'PPLC'),
          (5, 'PT', 'Lisbon Heights', 'Lisbon Heights', 38.8, -9.2, 1000, 'PPL'),
          (6, 'PT', 'New Lisbon', 'New Lisbon', 39.0, -9.0, 2000, 'PPL');
      ''');
    } finally {
      connection.dispose();
    }

    // Open the test catalog in read-only mode, just like production.
    geographyDatabase = GeographyDatabase.forTesting(
      sqlite3.sqlite3.open(databaseFile.path, mode: sqlite3.OpenMode.readOnly),
    );

    repository = LocalCityRepository(database: geographyDatabase);
  });

  tearDown(() async {
    await geographyDatabase.close();
    await directory.delete(recursive: true);
  });

  group('LocalCityRepository', () {
    test('finds cities by exact name', () async {
      final result = await repository.search(query: 'Paris');

      expect(result.total, 1);
      expect(result.items.single.name, 'Paris');
      expect(result.items.single.countryCode, 'FR');
    });

    test('ranks exact matches before prefix and substring matches', () async {
      final result = await repository.search(query: 'Lisbon');

      expect(result.total, 3);

      expect(result.items.map((city) => city.name).toList(), [
        'Lisbon',
        'Lisbon Heights',
        'New Lisbon',
      ]);
    });

    test('searches using ASCII city names', () async {
      final result = await repository.search(query: 'Sao');

      expect(result.total, 1);
      expect(result.items.single.name, 'São Paulo');
      expect(result.items.single.asciiName, 'Sao Paulo');
    });

    test('filters cities by country', () async {
      final result = await repository.search(countryCode: 'pt');

      expect(result.total, 4);

      expect(result.items.every((city) => city.countryCode == 'PT'), isTrue);
    });

    test('combines name search and country filter', () async {
      final result = await repository.search(
        query: 'Lisbon',
        countryCode: 'PT',
      );

      expect(result.total, 3);

      expect(result.items.every((city) => city.countryCode == 'PT'), isTrue);
    });

    test('orders country-only searches by population', () async {
      final result = await repository.search(countryCode: 'PT');

      expect(result.items.map((city) => city.name).toList(), [
        'Lisbon',
        'Porto',
        'New Lisbon',
        'Lisbon Heights',
      ]);
    });

    test('supports pagination', () async {
      final firstPage = await repository.search(
        countryCode: 'PT',
        limit: 2,
        offset: 0,
      );

      final secondPage = await repository.search(
        countryCode: 'PT',
        limit: 2,
        offset: 2,
      );

      expect(firstPage.total, 4);
      expect(firstPage.items.length, 2);
      expect(firstPage.limit, 2);
      expect(firstPage.offset, 0);

      expect(secondPage.total, 4);
      expect(secondPage.items.length, 2);
      expect(secondPage.offset, 2);

      final firstPageIds = firstPage.items.map((city) => city.id).toSet();

      final secondPageIds = secondPage.items.map((city) => city.id).toSet();

      expect(firstPageIds.intersection(secondPageIds), isEmpty);
    });

    test('returns empty results when no city matches', () async {
      final result = await repository.search(query: 'NonexistentCity123');

      expect(result.total, 0);
      expect(result.items, isEmpty);
    });

    test('rejects searches without query or country', () async {
      await expectLater(repository.search(), throwsArgumentError);
    });

    test('rejects invalid pagination parameters', () async {
      await expectLater(
        repository.search(query: 'Paris', limit: 0),
        throwsArgumentError,
      );

      await expectLater(
        repository.search(query: 'Paris', limit: 101),
        throwsArgumentError,
      );

      await expectLater(
        repository.search(query: 'Paris', offset: -1),
        throwsArgumentError,
      );
    });

    test('normalizes query whitespace', () async {
      final result = await repository.search(query: '  Paris  ');

      expect(result.total, 1);
      expect(result.items.single.name, 'Paris');
    });

    test('treats percent as a literal character', () async {
      final result = await repository.search(query: '%');

      expect(result.total, 0);
      expect(result.items, isEmpty);
    });

    test('treats underscore as a literal character', () async {
      final result = await repository.search(query: '_');

      expect(result.total, 0);
      expect(result.items, isEmpty);
    });

    test('maps all city fields correctly', () async {
      final result = await repository.search(query: 'Lisbon');

      final city = result.items.first;

      expect(city.id, 1);
      expect(city.name, 'Lisbon');
      expect(city.asciiName, 'Lisbon');
      expect(city.countryCode, 'PT');
      expect(city.countryName, 'Portugal');
      expect(city.latitude, 38.72);
      expect(city.longitude, -9.13);
      expect(city.population, 500000);
      expect(city.featureCode, 'PPLC');
    });
    test('resolves cities by IDs preserving requested order', () async {
      final cities = await repository.resolveByIds(cityIds: [4, 1, 3, 2]);

      expect(cities.map((city) => city.id).toList(), [4, 1, 3, 2]);

      expect(cities.map((city) => city.name).toList(), [
        'Paris',
        'Lisbon',
        'São Paulo',
        'Porto',
      ]);

      expect(cities[0].countryCode, 'FR');
      expect(cities[1].countryCode, 'PT');
      expect(cities[2].countryCode, 'BR');
    });
    test('resolves duplicate city IDs only once', () async {
      final cities = await repository.resolveByIds(cityIds: [1, 4, 1, 2, 4]);

      expect(cities.map((city) => city.id).toList(), [1, 4, 2]);
    });
    test('omits unknown city IDs', () async {
      final cities = await repository.resolveByIds(cityIds: [999, 1, 888, 4]);

      expect(cities.map((city) => city.id).toList(), [1, 4]);
    });
    test('returns empty results for empty city IDs', () async {
      final cities = await repository.resolveByIds(cityIds: []);

      expect(cities, isEmpty);
    });
    test('maps all resolved city fields correctly', () async {
      final cities = await repository.resolveByIds(cityIds: [3]);

      final city = cities.single;

      expect(city.id, 3);
      expect(city.name, 'São Paulo');
      expect(city.asciiName, 'Sao Paulo');
      expect(city.countryCode, 'BR');
      expect(city.countryName, 'Brazil');
      expect(city.latitude, -23.55);
      expect(city.longitude, -46.63);
      expect(city.population, 12000000);
      expect(city.featureCode, 'PPLA');
    });
    test('returns immutable resolved city lists', () async {
      final cities = await repository.resolveByIds(cityIds: [1, 2]);

      expect(() => cities.clear(), throwsUnsupportedError);
    });
    test('rejects invalid city IDs', () async {
      await expectLater(
        repository.resolveByIds(cityIds: [0]),
        throwsArgumentError,
      );

      await expectLater(
        repository.resolveByIds(cityIds: [-1]),
        throwsArgumentError,
      );

      await expectLater(
        repository.resolveByIds(
          cityIds: List.generate(201, (index) => index + 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
