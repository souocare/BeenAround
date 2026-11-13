import 'flight.dart';
import 'flight_timing.dart';

/// Detailed representation of a personal flight.
///
/// The flight is the persisted record.
/// Timing is calculated by the backend using IANA timezone rules.
class FlightDetail {
  const FlightDetail({required this.flight, required this.timing});

  final Flight flight;
  final FlightTiming timing;

  factory FlightDetail.fromJson(Map<String, dynamic> json) {
    final timingJson = json['timing'];

    if (timingJson is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid flight timing response.');
    }

    return FlightDetail(
      flight: Flight.fromJson(json),
      timing: FlightTiming.fromJson(timingJson),
    );
  }
}
