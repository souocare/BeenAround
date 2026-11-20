import '../domain/map_airport_data.dart';
import '../domain/map_search_destination.dart';

/// Returns the catalog ID of a selected airport when that airport
/// belongs to the user's completed-flight projection.
///
/// Selection remains independent of the user's travel records.
int? selectedUsedAirportId({
  required MapSearchDestination? selectedDestination,
  required Iterable<MapAirportData> usedAirports,
}) {
  if (selectedDestination?.type != MapSearchDestinationType.airport) {
    return null;
  }

  final destinationId = selectedDestination!.id;

  if (!destinationId.startsWith('airport:')) {
    return null;
  }

  final airportId = int.tryParse(destinationId.substring('airport:'.length));

  if (airportId == null) {
    return null;
  }

  for (final airport in usedAirports) {
    if (airport.airportId == airportId) {
      return airportId;
    }
  }

  return null;
}

/// Excludes the selected used airport from normal map rendering.
///
/// The selected airport remains visible through the independent
/// selection source, regardless of map zoom.
///
/// This function does not modify the original collection.
List<MapAirportData> excludeSelectedMapAirport({
  required Iterable<MapAirportData> airports,
  required int? selectedAirportId,
}) {
  return List<MapAirportData>.unmodifiable(
    airports.where((airport) => airport.airportId != selectedAirportId),
  );
}
