import 'city_visit.dart';
import '../../../core/models/visit_date_precision.dart';
import 'new_country_visit_input.dart';
import 'country_visit_date_expansion.dart';

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
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  });

  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  });

  Future<void> deleteCityVisit({required String visitId});
}
