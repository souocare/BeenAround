import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

class GeographyDatabase {
  GeographyDatabase._(this._database);

  @visibleForTesting
  GeographyDatabase.forTesting(sqlite3.Database database)
    : _database = database;

  static const assetPath = 'assets/geo/cities_catalog.sqlite';
  static const databaseName = 'beenaround_geography.sqlite';

  static const expectedSchemaVersion = '1';
  static const expectedCatalogVersion = '2026.10';

  final sqlite3.Database _database;

  /// Opens the bundled geography catalog.
  ///
  /// The catalog is copied to application storage on first launch
  /// or whenever its version changes.
  ///
  /// All connections are opened in read-only mode.
  static Future<GeographyDatabase> open() async {
    final directory = await getApplicationSupportDirectory();

    final databaseFile = File(p.join(directory.path, databaseName));

    if (!await _isCatalogCurrent(databaseFile)) {
      await _installCatalog(databaseFile);
    }

    final connection = sqlite3.sqlite3.open(
      databaseFile.path,
      mode: sqlite3.OpenMode.readOnly,
    );

    return GeographyDatabase._(connection);
  }

  /// Checks whether the installed catalog matches the expected versions.
  ///
  /// Missing, invalid, or incompatible catalogs are replaced with
  /// the bundled version.
  static Future<bool> _isCatalogCurrent(File file) async {
    if (!await file.exists()) {
      return false;
    }

    sqlite3.Database? database;

    try {
      database = sqlite3.sqlite3.open(
        file.path,
        mode: sqlite3.OpenMode.readOnly,
      );

      final rows = database.select('''
        SELECT key, value
        FROM catalog_metadata
        WHERE key IN ('schema_version', 'catalog_version')
      ''');

      final metadata = {
        for (final row in rows) row['key'] as String: row['value'] as String,
      };

      return metadata['schema_version'] == expectedSchemaVersion &&
          metadata['catalog_version'] == expectedCatalogVersion;
    } on sqlite3.SqliteException {
      return false;
    } finally {
      database?.dispose();
    }
  }

  /// Installs the bundled catalog using a temporary file.
  ///
  /// The existing catalog is only replaced after the asset has
  /// been completely written.
  static Future<void> _installCatalog(File destination) async {
    final data = await rootBundle.load(assetPath);

    final temporaryFile = File('${destination.path}.tmp');

    try {
      await temporaryFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );

      await temporaryFile.rename(destination.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  /// Executes a read-only SQL query.
  ///
  /// Parameters are passed separately to avoid SQL injection.
  Future<List<Map<String, Object?>>> select(
    String statement,
    List<Object?> arguments,
  ) async {
    final rows = _database.select(statement, arguments);

    return [
      for (final row in rows)
        {for (final column in row.keys) column: row[column]},
    ];
  }

  /// Releases the SQLite connection.
  Future<void> close() async {
    _database.close();
  }
}
