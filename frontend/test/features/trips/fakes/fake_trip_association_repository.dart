import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';

/// Shared in-memory fake for Trip presentation tests.
class FakeTripAssociationRepository implements TripAssociationRepository {
  FakeTripAssociationRepository({
    List<CountryVisit> countryVisits = const [],
    List<CityVisit> cityVisits = const [],
  }) : countryVisits = List.of(countryVisits),
       cityVisits = List.of(cityVisits);

  final List<CountryVisit> countryVisits;
  final List<CityVisit> cityVisits;
  Future<void> Function(String tripId, String visitId)? onAddCountryVisit;

  int addCountryVisitCalls = 0;

  @override
  Future<List<CountryVisit>> getCountryVisits({required String tripId}) async {
    return List.unmodifiable(countryVisits);
  }

  @override
  Future<List<CityVisit>> getCityVisits({required String tripId}) async {
    return List.unmodifiable(cityVisits);
  }

  @override
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    addCountryVisitCalls++;

    final handler = onAddCountryVisit;

    if (handler == null) {
      throw UnimplementedError(
        'Configure onAddCountryVisit for tests that add visits.',
      );
    }

    await handler(tripId, visitId);
  }

  @override
  Future<void> addCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeCountryVisit({
    required String tripId,
    required String visitId,
  }) async {
    countryVisits.removeWhere((visit) => visit.id == visitId);
  }

  @override
  Future<void> removeCityVisit({
    required String tripId,
    required String visitId,
  }) async {
    cityVisits.removeWhere((visit) => visit.id == visitId);
  }
}
