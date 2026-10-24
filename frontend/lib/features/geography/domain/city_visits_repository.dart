import 'city_visit.dart';

class CityVisitChanges {
  const CityVisitChanges({this.cityId, this.startedOn, this.endedOn});

  final int? cityId;
  final DateTime? startedOn;
  final DateTime? endedOn;
}

abstract interface class CityVisitsRepository {
  Future<List<CityVisit>> getCityVisits();

  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
  });

  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  });

  Future<void> deleteCityVisit({required String visitId});
}
