import '../domain/city_repository.dart';
import '../domain/city_search_result.dart';
import 'city_repository_handle.dart';
import '../domain/city_sort.dart';
import '../domain/country_city_count.dart';
import '../domain/city.dart';

typedef CityRepositoryHandleFactory = Future<CityRepositoryHandle> Function();

class LazyCityRepository implements CityRepository {
  LazyCityRepository({required CityRepositoryHandleFactory createHandle})
    : _createHandle = createHandle;

  final CityRepositoryHandleFactory _createHandle;

  Future<CityRepositoryHandle>? _pendingHandle;
  CityRepositoryHandle? _handle;

  bool _closed = false;

  @override
  Future<CitySearchResult> search({
    String? query,
    String? countryCode,
    int limit = 20,
    int offset = 0,
    CitySort sort = CitySort.population,
  }) async {
    if (_closed) {
      throw StateError('City repository is closed.');
    }

    final handle = await _getHandle();

    if (_closed) {
      throw StateError('City repository is closed.');
    }

    return handle.repository.search(
      query: query,
      countryCode: countryCode,
      limit: limit,
      offset: offset,
      sort: sort,
    );
  }

  @override
  Future<List<CountryCityCount>> listCountryCityCounts() async {
    if (_closed) {
      throw StateError('City repository is closed.');
    }

    final handle = await _getHandle();

    if (_closed) {
      throw StateError('City repository is closed.');
    }

    return handle.repository.listCountryCityCounts();
  }

  Future<CityRepositoryHandle> _getHandle() async {
    final existing = _handle;

    if (existing != null) {
      return existing;
    }

    final pending = _pendingHandle;

    if (pending != null) {
      return pending;
    }

    final initialization = _createHandle();

    _pendingHandle = initialization;

    try {
      final handle = await initialization;

      if (_closed) {
        await handle.close();
        throw StateError('City repository is closed.');
      }

      _handle = handle;

      return handle;
    } catch (_) {
      _pendingHandle = null;
      rethrow;
    }
  }

  @override
  Future<List<City>> resolveByIds({required List<int> cityIds}) async {
    if (_closed) {
      throw StateError('City repository is closed.');
    }

    final handle = await _getHandle();

    if (_closed) {
      throw StateError('City repository is closed.');
    }

    return handle.repository.resolveByIds(cityIds: cityIds);
  }

  Future<void> close() async {
    if (_closed) return;

    _closed = true;

    final handle = _handle;

    if (handle != null) {
      await handle.close();
      return;
    }

    // If initialization is still running, _getHandle()
    // will close the handle when initialization completes.
    final pending = _pendingHandle;

    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Initialization failure requires no resource cleanup.
      }
    }
  }
}
