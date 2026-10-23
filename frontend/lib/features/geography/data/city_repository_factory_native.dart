import '../../../core/network/api_client.dart';
import '../domain/city_repository.dart';
import 'city_repository_handle.dart';
import 'local/geography_database.dart';
import 'local/local_city_repository.dart';

Future<CityRepositoryHandle> createCityRepository({
  required ApiClient apiClient,
}) async {
  final database = await GeographyDatabase.open();

  return _LocalCityRepositoryHandle(database);
}

class _LocalCityRepositoryHandle implements CityRepositoryHandle {
  _LocalCityRepositoryHandle(this._database);

  final GeographyDatabase _database;

  @override
  late final CityRepository repository = LocalCityRepository(
    database: _database,
  );

  @override
  Future<void> close() => _database.close();
}
