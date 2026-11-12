import 'dart:async';

import 'package:beenaround/features/flights/application/flight_catalog_resolver.dart';
import 'package:beenaround/features/flights/application/flights_cubit.dart';
import 'package:beenaround/features/flights/application/flights_state.dart';
import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFlightRepository implements FlightRepository {
  final Map<int, FlightPage> pages = {};
  final List<int> requestedOffsets = [];

  bool failNextRequest = false;

  Completer<FlightPage>? pendingRequest;

  @override
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  }) async {
    requestedOffsets.add(offset);

    if (failNextRequest) {
      failNextRequest = false;
      throw StateError('Network unavailable');
    }

    final pending = pendingRequest;

    if (pending != null) {
      return pending.future;
    }

    return pages[offset]!;
  }

  @override
  Future<Flight> getFlight({required String flightId}) {
    throw UnimplementedError();
  }

  @override
  Future<Flight> createFlight({required FlightCreateInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<Flight> updateFlight({
    required String flightId,
    required FlightPatch patch,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFlight({required String flightId}) {
    throw UnimplementedError();
  }
}

class FakeAirportRepository implements AirportRepository {
  int requestCount = 0;

  @override
  Future<Airport> getAirport({required int airportId}) async {
    requestCount++;

    return Airport(
      id: airportId,
      ident: 'TEST$airportId',
      iataCode: airportId == 100 ? 'LIS' : 'OPO',
      name: 'Test Airport $airportId',
      type: 'large_airport',
      scheduledService: true,
    );
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
  int requestCount = 0;

  @override
  Future<Airline> getAirline({required int airlineId}) async {
    requestCount++;

    return Airline(id: airlineId, name: 'Test Airline $airlineId');
  }

  @override
  Future<AirlinePage> search({String? query, int limit = 20, int offset = 0}) {
    throw UnimplementedError();
  }
}

Flight makeFlight({
  required String id,
  int departureAirportId = 100,
  int arrivalAirportId = 200,
  int? airlineId,
}) {
  return Flight(
    id: id,
    departureAirportId: departureAirportId,
    arrivalAirportId: arrivalAirportId,
    departureOn: '2025-09-10',
    status: FlightStatus.flown,
    airlineId: airlineId,
    createdAt: DateTime.utc(2025, 9, 10),
    updatedAt: DateTime.utc(2025, 9, 10),
  );
}

FlightPage makePage({
  required List<Flight> items,
  required int total,
  required int offset,
  int limit = 20,
}) {
  return FlightPage(items: items, total: total, limit: limit, offset: offset);
}

void main() {
  late FakeFlightRepository flightRepository;
  late FakeAirportRepository airportRepository;
  late FakeAirlineRepository airlineRepository;
  late FlightCatalogResolver resolver;
  late FlightsCubit cubit;

  setUp(() {
    flightRepository = FakeFlightRepository();
    airportRepository = FakeAirportRepository();
    airlineRepository = FakeAirlineRepository();

    resolver = FlightCatalogResolver(
      airportRepository: airportRepository,
      airlineRepository: airlineRepository,
    );

    cubit = FlightsCubit(
      repository: flightRepository,
      catalogResolver: resolver,
      pageSize: 2,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state is empty', () {
    expect(cubit.state.phase, FlightsPhase.initial);
    expect(cubit.state.flights, isEmpty);
    expect(cubit.state.hasMore, isFalse);
  });

  test('loads first page and resolves catalog entries', () async {
    flightRepository.pages[0] = makePage(
      items: [
        makeFlight(id: '1', airlineId: 10),
        makeFlight(id: '2', airlineId: 10),
      ],
      total: 2,
      offset: 0,
      limit: 2,
    );

    await cubit.load();

    expect(cubit.state.phase, FlightsPhase.ready);
    expect(cubit.state.flights, hasLength(2));
    expect(cubit.state.total, 2);
    expect(cubit.state.hasMore, isFalse);

    expect(cubit.state.airportFor(100)?.displayCode, 'LIS');
    expect(cubit.state.airportFor(200)?.displayCode, 'OPO');

    expect(cubit.state.airlineFor(10)?.name, 'Test Airline 10');

    expect(airportRepository.requestCount, 2);
    expect(airlineRepository.requestCount, 1);
  });

  test('loads next page without losing previous flights', () async {
    flightRepository.pages[0] = makePage(
      items: [
        makeFlight(id: '1'),
        makeFlight(id: '2'),
      ],
      total: 3,
      offset: 0,
      limit: 2,
    );

    flightRepository.pages[2] = makePage(
      items: [makeFlight(id: '3')],
      total: 3,
      offset: 2,
      limit: 2,
    );

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.flights.map((flight) => flight.id), ['1', '2', '3']);

    expect(cubit.state.hasMore, isFalse);
    expect(flightRepository.requestedOffsets, [0, 2]);
  });

  test('deduplicates flights across pages', () async {
    flightRepository.pages[0] = makePage(
      items: [
        makeFlight(id: '1'),
        makeFlight(id: '2'),
      ],
      total: 3,
      offset: 0,
      limit: 2,
    );

    flightRepository.pages[2] = makePage(
      items: [
        makeFlight(id: '2'),
        makeFlight(id: '3'),
      ],
      total: 3,
      offset: 2,
      limit: 2,
    );

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.flights.map((flight) => flight.id), ['1', '2', '3']);
  });

  test('refresh replaces the previous first page', () async {
    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: 'old')],
      total: 1,
      offset: 0,
      limit: 2,
    );

    await cubit.load();

    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: 'new')],
      total: 1,
      offset: 0,
      limit: 2,
    );

    await cubit.refresh();

    expect(cubit.state.flights.map((flight) => flight.id), ['new']);

    expect(flightRepository.requestedOffsets, [0, 0]);
  });

  test('initial loading failure is recoverable', () async {
    flightRepository.failNextRequest = true;

    await cubit.load();

    expect(cubit.state.phase, FlightsPhase.failure);
    expect(cubit.state.errorMessage, isNotNull);

    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: '1')],
      total: 1,
      offset: 0,
      limit: 2,
    );

    await cubit.load();

    expect(cubit.state.phase, FlightsPhase.ready);
    expect(cubit.state.flights, hasLength(1));
  });

  test('does not fetch additional pages unnecessarily', () async {
    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: '1')],
      total: 1,
      offset: 0,
      limit: 2,
    );

    await cubit.load();
    await cubit.loadMore();

    expect(flightRepository.requestedOffsets, [0]);
  });

  test('pagination failure preserves loaded flights', () async {
    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: '1')],
      total: 3,
      offset: 0,
      limit: 2,
    );

    await cubit.load();

    flightRepository.failNextRequest = true;

    await cubit.loadMore();

    expect(cubit.state.phase, FlightsPhase.ready);
    expect(cubit.state.flights, hasLength(1));
    expect(cubit.state.hasMore, isTrue);
    expect(cubit.state.loadMoreError, isNotNull);
  });

  test('retry after pagination failure uses same offset', () async {
    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: '1')],
      total: 2,
      offset: 0,
      limit: 2,
    );

    flightRepository.pages[1] = makePage(
      items: [makeFlight(id: '2')],
      total: 2,
      offset: 1,
      limit: 2,
    );

    await cubit.load();

    flightRepository.failNextRequest = true;
    await cubit.loadMore();

    await cubit.loadMore();

    expect(flightRepository.requestedOffsets, [0, 1, 1]);
    expect(cubit.state.flights, hasLength(2));
  });

  test('prevents concurrent pagination requests', () async {
    flightRepository.pages[0] = makePage(
      items: [makeFlight(id: '1')],
      total: 2,
      offset: 0,
      limit: 2,
    );

    await cubit.load();

    final pending = Completer<FlightPage>();
    flightRepository.pendingRequest = pending;

    final first = cubit.loadMore();
    final second = cubit.loadMore();

    expect(flightRepository.requestedOffsets, [0, 1]);

    pending.complete(
      makePage(items: [makeFlight(id: '2')], total: 2, offset: 1, limit: 2),
    );

    await Future.wait([first, second]);

    expect(cubit.state.flights, hasLength(2));
    expect(flightRepository.requestedOffsets, [0, 1]);
  });
}
