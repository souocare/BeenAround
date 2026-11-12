/// Explicit status of a personal flight.
enum FlightStatus {
  flown('flown'),
  planned('planned');

  const FlightStatus(this.apiValue);

  final String apiValue;

  static FlightStatus fromJson(String value) {
    return FlightStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw FormatException('Invalid flight status: $value'),
    );
  }
}

/// Passenger cabin classification.
enum FlightCabinClass {
  economy('economy'),
  premiumEconomy('premium_economy'),
  business('business'),
  first('first');

  const FlightCabinClass(this.apiValue);

  final String apiValue;

  static FlightCabinClass fromJson(String value) {
    return FlightCabinClass.values.firstWhere(
      (cabin) => cabin.apiValue == value,
      orElse: () => throw FormatException('Invalid cabin class: $value'),
    );
  }
}

/// One personal flight segment.
///
/// Flights are independent travel records. They do not automatically
/// create visits or belong to a Trip.
///
/// Calendar dates and times are preserved as local values.
/// They must not be converted using the device's timezone.
class Flight {
  const Flight({
    required this.id,
    required this.departureAirportId,
    required this.arrivalAirportId,
    required this.departureOn,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.airlineId,
    this.airlineName,
    this.flightNumber,
    this.departureTime,
    this.arrivalOn,
    this.arrivalTime,
    this.aircraftType,
    this.aircraftRegistration,
    this.seat,
    this.cabinClass,
    this.notes,
  });

  final String id;

  final int departureAirportId;
  final int arrivalAirportId;

  final int? airlineId;
  final String? airlineName;
  final String? flightNumber;

  /// Departure airport's local calendar date (YYYY-MM-DD).
  final String departureOn;

  /// Departure airport's local time (HH:mm or HH:mm:ss[.fraction]).
  final String? departureTime;

  /// Arrival airport's local calendar date.
  final String? arrivalOn;

  /// Arrival airport's local time.
  final String? arrivalTime;

  final FlightStatus status;

  final String? aircraftType;
  final String? aircraftRegistration;
  final String? seat;
  final FlightCabinClass? cabinClass;
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFlown => status == FlightStatus.flown;

  bool get isPlanned => status == FlightStatus.planned;

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id'] as String,
      departureAirportId: json['departure_airport_id'] as int,
      arrivalAirportId: json['arrival_airport_id'] as int,
      airlineId: json['airline_id'] as int?,
      airlineName: json['airline_name'] as String?,
      flightNumber: json['flight_number'] as String?,
      departureOn: json['departure_on'] as String,
      departureTime: json['departure_time'] as String?,
      arrivalOn: json['arrival_on'] as String?,
      arrivalTime: json['arrival_time'] as String?,
      status: FlightStatus.fromJson(json['status'] as String),
      aircraftType: json['aircraft_type'] as String?,
      aircraftRegistration: json['aircraft_registration'] as String?,
      seat: json['seat'] as String?,
      cabinClass: json['cabin_class'] == null
          ? null
          : FlightCabinClass.fromJson(json['cabin_class'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// A paginated response from the personal flights API.
class FlightPage {
  const FlightPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Flight> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory FlightPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Invalid flights list response.');
    }

    return FlightPage(
      items: List.unmodifiable(
        rawItems.map(
          (item) => Flight.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
