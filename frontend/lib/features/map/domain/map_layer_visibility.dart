/// Controls which geographic information layers are visible
/// on the interactive Map.
///
/// This is presentation state only.
///
/// Visibility does not modify recorded travel history,
/// geographic visits, flights, wishlists or Trips.
///
/// Destination-status filtering (Visited / Lived / Wishlist)
/// is handled independently.
class MapLayerVisibility {
  const MapLayerVisibility({
    this.countries = true,
    this.cities = true,
    this.airports = true,
    this.flightRoutes = true,
  });

  final bool countries;
  final bool cities;
  final bool airports;
  final bool flightRoutes;

  MapLayerVisibility copyWith({
    bool? countries,
    bool? cities,
    bool? airports,
    bool? flightRoutes,
  }) {
    return MapLayerVisibility(
      countries: countries ?? this.countries,
      cities: cities ?? this.cities,
      airports: airports ?? this.airports,
      flightRoutes: flightRoutes ?? this.flightRoutes,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapLayerVisibility &&
            other.countries == countries &&
            other.cities == cities &&
            other.airports == airports &&
            other.flightRoutes == flightRoutes;
  }

  @override
  int get hashCode => Object.hash(countries, cities, airports, flightRoutes);
}
