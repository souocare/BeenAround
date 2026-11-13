import 'airline.dart';

/// An explicitly selected airline for a personal flight.
///
/// A selection references either a catalog airline or a manual name.
/// It never represents both simultaneously.
class AirlineSelection {
  const AirlineSelection._({this.airline, this.manualName});

  factory AirlineSelection.catalog(Airline airline) {
    return AirlineSelection._(airline: airline);
  }

  factory AirlineSelection.manual(String name) {
    final normalized = name.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Manual airline name cannot be empty.',
      );
    }

    return AirlineSelection._(manualName: normalized);
  }

  final Airline? airline;
  final String? manualName;

  bool get isCatalog => airline != null;

  bool get isManual => manualName != null;

  int? get airlineId => airline?.id;

  String? get airlineName => manualName;

  String get displayName => airline?.name ?? manualName!;

  Map<String, dynamic> toFlightFields() {
    return {'airline_id': airlineId, 'airline_name': airlineName};
  }
}
