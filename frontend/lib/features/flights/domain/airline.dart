/// An airline from the shared aviation catalog.
class Airline {
  const Airline({
    required this.id,
    required this.name,
    this.iataCode,
    this.icaoCode,
    this.callsign,
    this.countryName,
  });

  final int id;
  final String name;

  final String? iataCode;
  final String? icaoCode;

  final String? callsign;
  final String? countryName;

  String? get displayCode => iataCode ?? icaoCode;

  String get displayName {
    final code = displayCode;

    if (code == null || code.isEmpty) {
      return name;
    }

    return '$code · $name';
  }

  factory Airline.fromJson(Map<String, dynamic> json) {
    return Airline(
      id: json['id'] as int,
      name: json['name'] as String,
      iataCode: json['iata_code'] as String?,
      icaoCode: json['icao_code'] as String?,
      callsign: json['callsign'] as String?,
      countryName: json['country_name'] as String?,
    );
  }
}

/// Paginated airline catalog response.
class AirlinePage {
  const AirlinePage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Airline> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory AirlinePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Invalid airline catalog response.');
    }

    final total = json['total'];
    final limit = json['limit'];
    final offset = json['offset'];

    if (total is! int || limit is! int || offset is! int) {
      throw const FormatException('Invalid airline pagination metadata.');
    }

    final airlines = rawItems
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid airline item.');
          }

          return Airline.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);

    return AirlinePage(
      items: List.unmodifiable(airlines),
      total: total,
      limit: limit,
      offset: offset,
    );
  }
}
