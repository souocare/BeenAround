import 'trip.dart';
import 'trip_input.dart';

/// Operations supported for user-owned Trips.
abstract interface class TripRepository {
  /// Return the authenticated user's Trips.
  Future<List<Trip>> getTrips();

  /// Retrieve one Trip.
  Future<Trip> getTrip({required String tripId});

  /// Create a new Trip belonging to the authenticated user.
  Future<Trip> createTrip({required TripInput input});

  /// Replace the editable fields of an existing Trip.
  Future<Trip> updateTrip({required String tripId, required TripInput input});

  /// Delete a Trip without deleting its independent travel records.
  Future<void> deleteTrip({required String tripId});
}
