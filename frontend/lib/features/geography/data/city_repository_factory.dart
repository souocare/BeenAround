import '../../../core/network/api_client.dart';
import 'city_repository_handle.dart';

import 'city_repository_factory_native.dart'
    if (dart.library.js_interop) 'city_repository_factory_web.dart'
    as platform;

Future<CityRepositoryHandle> createCityRepository({
  required ApiClient apiClient,
}) {
  return platform.createCityRepository(apiClient: apiClient);
}
