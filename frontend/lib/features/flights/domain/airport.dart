/// One airport from the shared aviation catalog.
///
/// Airport transit does not imply that the user visited its country.
class Airport {
  const Airport({
    required this.id,
    required this.ident,
    required this.name,
    required this.type,
    required this.scheduledService,
    this.iataCode,
    this.icaoCode,
    this.municipality,
    this.sourceCountryCode,
    this.countryCode,
    this.countryName,
    this.latitude,
    this.longitude,
  });

  final int id;

  /// OurAirports identifier, such as LPPT.
  final String ident;

  final String? iataCode;
  final String? icaoCode;

  final String name;
  final String? municipality;

  final String? sourceCountryCode;
  final String? countryCode;
  final String? countryName;

  final double? latitude;
  final double? longitude;

  final String type;
  final bool scheduledService;

  /// Preferred code for compact flight cards.
  ///
  /// IATA is usually the most recognizable passenger-facing code.
  /// ICAO and ident are fallbacks for airports without IATA codes.
  String get displayCode => iataCode ?? icaoCode ?? ident;

  String get displayLocation {
    final city = municipality?.trim();
    final country = countryName?.trim();

    if (city != null && city.isNotEmpty) {
      if (country != null && country.isNotEmpty) {
        return '$city, $country';
      }

      return city;
    }

    if (country != null && country.isNotEmpty) {
      return country;
    }

    return name;
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      id: json['id'] as int,
      ident: json['ident'] as String,
      iataCode: json['iata_code'] as String?,
      icaoCode: json['icao_code'] as String?,
      name: json['name'] as String,
      municipality: json['municipality'] as String?,
      sourceCountryCode: json['source_country_code'] as String?,
      countryCode: json['country_code'] as String?,
      countryName: json['country_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      type: json['type'] as String,
      scheduledService: json['scheduled_service'] as bool,
    );
  }
}

/// Paginated airport catalog response.
class AirportPage {
  const AirportPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Airport> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory AirportPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Invalid airport catalog response.');
    }

    final total = json['total'];
    final limit = json['limit'];
    final offset = json['offset'];

    if (total is! int || limit is! int || offset is! int) {
      throw const FormatException('Invalid airport pagination metadata.');
    }

    final airports = rawItems
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid airport item.');
          }

          return Airport.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);

    return AirportPage(
      items: List.unmodifiable(airports),
      total: total,
      limit: limit,
      offset: offset,
    );
  }
}
