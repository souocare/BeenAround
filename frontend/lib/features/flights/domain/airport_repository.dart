import 'airport.dart';

/// Operations supported by the shared airport catalog.
abstract interface class AirportRepository {
  /// Search airports by code, name or municipality.
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  });

  /// Resolve one airport by its catalog ID.
  Future<Airport> getAirport({required int airportId});
}
