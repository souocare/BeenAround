import 'airline.dart';

/// Operations supported by the shared airline catalog.
abstract interface class AirlineRepository {
  /// Search airlines by name or aviation code.
  Future<AirlinePage> search({String? query, int limit = 20, int offset = 0});

  /// Resolve one airline by its catalog ID.
  Future<Airline> getAirline({required int airlineId});
}
