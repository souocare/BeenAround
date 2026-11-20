import '../../flights/domain/airport.dart';
import '../../geography/domain/city.dart';

/// Geographic destination categories supported by Map search.
enum MapSearchDestinationType { country, city, airport }

/// Read-only geographic search result.
///
/// Search results originate from shared geographic catalogs.
///
/// They do not represent visits, residences, wishlist entries
/// or any other user-owned travel records.
class MapSearchDestination {
  const MapSearchDestination({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.airportCode,
    this.airportLocation,
  });

  final MapSearchDestinationType type;

  /// Stable, globally unique search-result identifier.
  ///
  /// Includes the destination type to prevent collisions
  /// between catalog identifiers.
  final String id;

  /// Primary name displayed in search results.
  final String title;

  /// Geographic context displayed below the destination name.
  final String subtitle;

  final String? countryCode;

  final double? latitude;
  final double? longitude;

  /// Airport code displayed in search results (IATA or fallback).
  final String? airportCode;

  /// Human-readable airport location.
  final String? airportLocation;

  /// Whether the destination has usable geographic coordinates.
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  /// Creates a search result for a country.
  ///
  /// Country camera navigation uses the existing country geometry.
  factory MapSearchDestination.country({
    required String code,
    required String name,
  }) {
    final normalizedCode = code.trim().toUpperCase();

    return MapSearchDestination(
      type: MapSearchDestinationType.country,
      id: 'country:$normalizedCode',
      title: name,
      subtitle: normalizedCode,
      countryCode: normalizedCode,
    );
  }

  /// Creates a search result from a shared city catalog entry.
  factory MapSearchDestination.city(City city) {
    return MapSearchDestination(
      type: MapSearchDestinationType.city,
      id: 'city:${city.id}',
      title: city.name,
      subtitle: city.countryName,
      countryCode: city.countryCode,
      latitude: city.latitude,
      longitude: city.longitude,
    );
  }

  /// Creates a search result from a shared airport catalog entry.
  factory MapSearchDestination.airport(Airport airport) {
    return MapSearchDestination(
      type: MapSearchDestinationType.airport,
      id: 'airport:${airport.id}',
      title: airport.name,
      subtitle: '${airport.displayCode} · ${airport.displayLocation}',
      countryCode: airport.countryCode,
      latitude: airport.latitude,
      longitude: airport.longitude,
      airportCode: airport.displayCode,
      airportLocation: airport.displayLocation,
    );
  }
}
