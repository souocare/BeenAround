import '../../../core/network/api_client.dart';
import '../domain/city_repository.dart';
import 'city_repository_handle.dart';
import 'remote/api_city_repository.dart';

Future<CityRepositoryHandle> createCityRepository({
  required ApiClient apiClient,
}) async {
  return _WebCityRepositoryHandle(ApiCityRepository(apiClient: apiClient));
}

class _WebCityRepositoryHandle implements CityRepositoryHandle {
  _WebCityRepositoryHandle(this.repository);

  @override
  final CityRepository repository;

  @override
  Future<void> close() async {
    // ApiClient lifecycle is managed by AuthenticationGateway.
  }
}
