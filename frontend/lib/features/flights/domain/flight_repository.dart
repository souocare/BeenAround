import 'flight.dart';
import 'flight_input.dart';

/// Operations supported for authenticated personal flights.
abstract interface class FlightRepository {
  /// Retrieve a paginated list of the user's flights.
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  });

  /// Retrieve one user-owned flight.
  Future<Flight> getFlight({required String flightId});

  /// Create an independent personal flight record.
  Future<Flight> createFlight({required FlightCreateInput input});

  /// Apply an explicit partial update to an owned flight.
  Future<Flight> updateFlight({
    required String flightId,
    required FlightPatch patch,
  });

  /// Delete an owned flight without deleting visits or Trips.
  Future<void> deleteFlight({required String flightId});
}
