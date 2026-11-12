import 'dart:async';

import 'package:beenaround/features/flights/application/flight_catalog_resolver.dart';
import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAirportRepository implements AirportRepository {
  final Map<int, Airport> airports = {};
  final Map<int, int> requests = {};

  bool failNextRequest = false;

  @override
  Future<Airport> getAirport({required int airportId}) async {
    requests[airportId] = (requests[airportId] ?? 0) + 1;

    if (failNextRequest) {
      failNextRequest = false;
      throw StateError('Airport unavailable');
    }

    return airports[airportId]!;
  }

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }
}

class FakeAirlineRepository implements AirlineRepository {
  final Map<int, Airline> airlines = {};
  final Map<int, int> requests = {};

  @override
  Future<Airline> getAirline({required int airlineId}) async {
    requests[airlineId] = (requests[airlineId] ?? 0) + 1;

    return airlines[airlineId]!;
  }

  @override
  Future<AirlinePage> search({String? query, int limit = 20, int offset = 0}) {
    throw UnimplementedError();
  }
}

class DelayedAirportRepository implements AirportRepository {
  final Completer<Airport> completer = Completer<Airport>();

  int requestCount = 0;

  @override
  Future<Airport> getAirport({required int airportId}) {
    requestCount++;

    return completer.future;
  }

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }
}

Airport airport(int id, String code) {
  return Airport(
    id: id,
    ident: code,
    iataCode: code,
    name: '$code Airport',
    type: 'large_airport',
    scheduledService: true,
  );
}

Airline airline(int id, String name) {
  return Airline(id: id, name: name);
}

Flight flight({
  required String id,
  required int departureAirportId,
  required int arrivalAirportId,
  int? airlineId,
  String? airlineName,
}) {
  return Flight(
    id: id,
    departureAirportId: departureAirportId,
    arrivalAirportId: arrivalAirportId,
    departureOn: '2025-09-10',
    status: FlightStatus.flown,
    airlineId: airlineId,
    airlineName: airlineName,
    createdAt: DateTime.utc(2025, 9, 10),
    updatedAt: DateTime.utc(2025, 9, 10),
  );
}

void main() {
  late FakeAirportRepository airportRepository;
  late FakeAirlineRepository airlineRepository;
  late FlightCatalogResolver resolver;

  setUp(() {
    airportRepository = FakeAirportRepository()
      ..airports.addAll({
        100: airport(100, 'LIS'),
        200: airport(200, 'OPO'),
        300: airport(300, 'LHR'),
      });

    airlineRepository = FakeAirlineRepository()
      ..airlines.addAll({
        10: airline(10, 'TAP Air Portugal'),
        20: airline(20, 'British Airways'),
      });

    resolver = FlightCatalogResolver(
      airportRepository: airportRepository,
      airlineRepository: airlineRepository,
    );
  });

  test('resolves unique airports and airlines', () async {
    final catalog = await resolver.resolve([
      flight(
        id: '1',
        departureAirportId: 100,
        arrivalAirportId: 200,
        airlineId: 10,
      ),
      flight(
        id: '2',
        departureAirportId: 200,
        arrivalAirportId: 100,
        airlineId: 10,
      ),
      flight(
        id: '3',
        departureAirportId: 100,
        arrivalAirportId: 300,
        airlineId: 20,
      ),
    ]);

    expect(catalog.airports.keys, containsAll([100, 200, 300]));

    expect(catalog.airlines.keys, containsAll([10, 20]));

    expect(airportRepository.requests, {100: 1, 200: 1, 300: 1});

    expect(airlineRepository.requests, {10: 1, 20: 1});
  });

  test('reuses cached catalog entries', () async {
    final firstFlight = flight(
      id: '1',
      departureAirportId: 100,
      arrivalAirportId: 200,
      airlineId: 10,
    );

    await resolver.resolve([firstFlight]);

    final catalog = await resolver.resolve([firstFlight]);

    expect(catalog.airportFor(100)?.displayCode, 'LIS');

    expect(airportRepository.requests[100], 1);
    expect(airportRepository.requests[200], 1);
    expect(airlineRepository.requests[10], 1);
  });

  test('supports manual airline names', () async {
    final manualFlight = flight(
      id: '1',
      departureAirportId: 100,
      arrivalAirportId: 200,
      airlineName: 'Air Berlin',
    );

    final catalog = await resolver.resolve([manualFlight]);

    expect(catalog.airlineNameFor(manualFlight), 'Air Berlin');

    expect(airlineRepository.requests, isEmpty);
  });

  test('returns a snapshot containing only requested references', () async {
    await resolver.resolve([
      flight(id: '1', departureAirportId: 100, arrivalAirportId: 200),
    ]);

    final catalog = await resolver.resolve([
      flight(id: '2', departureAirportId: 100, arrivalAirportId: 300),
    ]);

    expect(catalog.airports.keys, containsAll([100, 300]));
    expect(catalog.airports.containsKey(200), isFalse);
  });

  test('failed requests are retried', () async {
    airportRepository.failNextRequest = true;

    final targetFlight = flight(
      id: '1',
      departureAirportId: 100,
      arrivalAirportId: 200,
    );

    await expectLater(resolver.resolve([targetFlight]), throwsStateError);

    final catalog = await resolver.resolve([targetFlight]);

    expect(catalog.airportFor(100), isNotNull);
    expect(catalog.airportFor(200), isNotNull);

    expect(airportRepository.requests[100], 2);
  });

  test('clear removes successful cache entries', () async {
    final targetFlight = flight(
      id: '1',
      departureAirportId: 100,
      arrivalAirportId: 200,
      airlineId: 10,
    );

    await resolver.resolve([targetFlight]);

    resolver.clear();

    await resolver.resolve([targetFlight]);

    expect(airportRepository.requests[100], 2);
    expect(airportRepository.requests[200], 2);
    expect(airlineRepository.requests[10], 2);
  });
  test('concurrent resolution shares pending requests', () async {
    final delayedRepository = DelayedAirportRepository();

    final concurrentResolver = FlightCatalogResolver(
      airportRepository: delayedRepository,
      airlineRepository: airlineRepository,
    );

    final targetFlight = flight(
      id: '1',
      departureAirportId: 100,
      arrivalAirportId: 100,
    );

    final first = concurrentResolver.resolve([targetFlight]);
    final second = concurrentResolver.resolve([targetFlight]);

    expect(delayedRepository.requestCount, 1);

    delayedRepository.completer.complete(airport(100, 'LIS'));

    final catalogs = await Future.wait([first, second]);

    expect(catalogs, hasLength(2));
    expect(catalogs.first.airportFor(100)?.displayCode, 'LIS');
    expect(catalogs.last.airportFor(100)?.displayCode, 'LIS');
  });
}
