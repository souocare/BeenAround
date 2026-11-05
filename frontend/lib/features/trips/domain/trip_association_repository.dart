import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_visit.dart';

/// Operations for associating existing travel records with Trips.
///
/// Visits remain independent of Trips. Removing an association
/// must never delete the underlying visit.
///
/// All operations are scoped to the authenticated user.
abstract interface class TripAssociationRepository {
  /// Return country visits explicitly associated with a Trip.
  Future<List<CountryVisit>> getCountryVisits({required String tripId});

  /// Return city visits explicitly associated with a Trip.
  Future<List<CityVisit>> getCityVisits({required String tripId});

  /// Associate an existing country visit with a Trip.
  ///
  /// The backend treats repeated associations as successful.
  Future<void> addCountryVisit({
    required String tripId,
    required String visitId,
  });

  /// Associate an existing city visit with a Trip.
  Future<void> addCityVisit({required String tripId, required String visitId});

  /// Remove a country visit association.
  ///
  /// The original CountryVisit remains available in Explore.
  Future<void> removeCountryVisit({
    required String tripId,
    required String visitId,
  });

  /// Remove a city visit association.
  ///
  /// The original CityVisit remains available in Geography.
  Future<void> removeCityVisit({
    required String tripId,
    required String visitId,
  });
}
