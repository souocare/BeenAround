import '../domain/city_repository.dart';

abstract interface class CityRepositoryHandle {
  CityRepository get repository;

  Future<void> close();
}
