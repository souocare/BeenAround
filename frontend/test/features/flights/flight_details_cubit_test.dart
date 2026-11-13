import 'dart:async';

import 'package:beenaround/features/flights/application/flight_catalog_resolver.dart';
import 'package:beenaround/features/flights/application/flight_details_cubit.dart';
import 'package:beenaround/features/flights/application/flight_details_state.dart';

import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake flight repository
// ---------------------------------------------------------------------------

class FakeDetailsFlightRepository extends Fake implements FlightRepository {
  final Map<String, Flight> flights = {};

  final Map<String, Completer<Flight>> pendingRequests = {};

  final List<String> requestedIds = [];

  bool failNextRequest = false;

  @override
  Future<Flight> getFlight({required String flightId}) async {
    requestedIds.add(flightId);

    if (failNextRequest) {
      failNextRequest = false;
      throw StateError('Network unavailable');
    }

    final pending = pendingRequests[flightId];

    if (pending != null) {
      return pending.future;
    }

    final flight = flights[flightId];

    if (flight == null) {
      throw StateError('Flight not found');
    }

    return flight;
  }
}

// ---------------------------------------------------------------------------
// Fake airport repository
// ---------------------------------------------------------------------------

class FakeDetailsAirportRepository extends Fake implements AirportRepository {
  final Map<int, Airport> airports = {};

  final Map<int, int> requests = {};

  final Set<int> failingIds = {};

  @override
  Future<Airport> getAirport({required int airportId}) async {
    requests[airportId] = (requests[airportId] ?? 0) + 1;

    if (failingIds.contains(airportId)) {
      throw StateError('Airport unavailable');
    }

    final airport = airports[airportId];

    if (airport == null) {
      throw StateError('Unknown airport');
    }

    return airport;
  }
}

// ---------------------------------------------------------------------------
// Fake airline repository
// ---------------------------------------------------------------------------

class FakeDetailsAirlineRepository extends Fake implements AirlineRepository {
  final Map<int, Airline> airlines = {};

  final Map<int, int> requests = {};

  final Set<int> failingIds = {};

  @override
  Future<Airline> getAirline({required int airlineId}) async {
    requests[airlineId] = (requests[airlineId] ?? 0) + 1;

    if (failingIds.contains(airlineId)) {
      throw StateError('Airline unavailable');
    }

    final airline = airlines[airlineId];

    if (airline == null) {
      throw StateError('Unknown airline');
    }

    return airline;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Flight makeFlight({
  required String id,
  int departureAirportId = 100,
  int arrivalAirportId = 200,
  int? airlineId = 10,
  String? airlineName,
}) {
  return Flight(
    id: id,
    departureAirportId: departureAirportId,
    arrivalAirportId: arrivalAirportId,
    departureOn: '2026-10-10',
    departureTime: '19:20',
    arrivalOn: '2026-10-10',
    arrivalTime: '22:15',
    status: FlightStatus.flown,
    airlineId: airlineId,
    airlineName: airlineName,
    flightNumber: 'TP1019',
    createdAt: DateTime.utc(2026, 10, 10),
    updatedAt: DateTime.utc(2026, 10, 10),
  );
}

Airport makeAirport(int id, String code) {
  return Airport(
    id: id,
    ident: 'TEST$id',
    iataCode: code,
    name: '$code Airport',
    type: 'large_airport',
    scheduledService: true,
  );
}

Airline makeAirline(int id, String name) {
  return Airline(id: id, name: name, iataCode: 'TP');
}

/// Flushes pending asynchronous continuations without
/// introducing arbitrary real-time delays.
Future<void> flushAsync() async {
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeDetailsFlightRepository flightRepository;
  late FakeDetailsAirportRepository airportRepository;
  late FakeDetailsAirlineRepository airlineRepository;

  late FlightCatalogResolver resolver;
  late FlightDetailsCubit cubit;

  setUp(() {
    flightRepository = FakeDetailsFlightRepository();

    airportRepository = FakeDetailsAirportRepository()
      ..airports.addAll({
        100: makeAirport(100, 'LIS'),
        200: makeAirport(200, 'BCN'),
        300: makeAirport(300, 'LHR'),
      });

    airlineRepository = FakeDetailsAirlineRepository()
      ..airlines[10] = makeAirline(10, 'TAP Air Portugal');

    resolver = FlightCatalogResolver(
      airportRepository: airportRepository,
      airlineRepository: airlineRepository,
    );

    cubit = FlightDetailsCubit(
      repository: flightRepository,
      catalogResolver: resolver,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('starts in initial state', () {
    expect(cubit.state.phase, FlightDetailsPhase.initial);

    expect(cubit.state.flight, isNull);

    expect(cubit.state.departureAirport, isNull);
    expect(cubit.state.arrivalAirport, isNull);
    expect(cubit.state.airline, isNull);

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.isReady, isFalse);
    expect(cubit.state.hasError, isFalse);
  });

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  test('transitions from loading to ready', () async {
    final flight = makeFlight(id: 'flight-1');

    final pending = Completer<Flight>();

    flightRepository.pendingRequests['flight-1'] = pending;

    final phases = <FlightDetailsPhase>[];

    final subscription = cubit.stream.listen((state) {
      phases.add(state.phase);
    });

    try {
      final loadFuture = cubit.load('flight-1');

      await flushAsync();

      expect(cubit.state.phase, FlightDetailsPhase.loading);

      pending.complete(flight);

      await loadFuture;
      await flushAsync();

      expect(cubit.state.phase, FlightDetailsPhase.ready);

      expect(cubit.state.flight?.id, 'flight-1');

      expect(phases, [
        FlightDetailsPhase.loading,
        FlightDetailsPhase.ready,
        FlightDetailsPhase.ready,
      ]);
    } finally {
      await subscription.cancel();
    }
  });

  // -------------------------------------------------------------------------
  // Catalog metadata
  // -------------------------------------------------------------------------

  test('resolves airports and airline', () async {
    final flight = makeFlight(id: 'flight-1');

    flightRepository.flights[flight.id] = flight;

    await cubit.load(flight.id);

    final state = cubit.state;

    expect(state.isReady, isTrue);

    expect(state.flight?.id, flight.id);

    expect(state.departureAirport?.displayCode, 'LIS');

    expect(state.arrivalAirport?.displayCode, 'BCN');

    expect(state.airline?.name, 'TAP Air Portugal');

    expect(state.airlineName, 'TAP Air Portugal');

    expect(airportRepository.requests[100], 1);
    expect(airportRepository.requests[200], 1);
    expect(airlineRepository.requests[10], 1);
  });

  test('supports manually entered airline names', () async {
    final flight = makeFlight(
      id: 'flight-manual',
      airlineId: null,
      airlineName: 'Air Berlin',
    );

    flightRepository.flights[flight.id] = flight;

    await cubit.load(flight.id);

    expect(cubit.state.isReady, isTrue);

    expect(cubit.state.airlineName, 'Air Berlin');

    expect(cubit.state.airline, isNull);

    // Manual airlines do not trigger catalog lookups.
    expect(airlineRepository.requests, isEmpty);
  });

  // -------------------------------------------------------------------------
  // Errors and retry
  // -------------------------------------------------------------------------

  test('shows an error when flight loading fails', () async {
    flightRepository.failNextRequest = true;

    await cubit.load('flight-1');

    expect(cubit.state.hasError, isTrue);

    expect(cubit.state.phase, FlightDetailsPhase.failure);

    expect(cubit.state.errorMessage, 'Unable to load this flight.');

    expect(cubit.state.flight, isNull);
  });

  test('can retry after a failed request', () async {
    final flight = makeFlight(id: 'flight-1');

    flightRepository.flights[flight.id] = flight;

    flightRepository.failNextRequest = true;

    await cubit.load(flight.id);

    expect(cubit.state.hasError, isTrue);

    await cubit.load(flight.id);

    expect(cubit.state.isReady, isTrue);

    expect(cubit.state.flight?.id, flight.id);

    expect(flightRepository.requestedIds, ['flight-1', 'flight-1']);
  });

  // -------------------------------------------------------------------------
  // Partial catalog resolution
  // -------------------------------------------------------------------------

  test('keeps the flight visible when an airline lookup fails', () async {
    final flight = makeFlight(id: 'flight-1');

    flightRepository.flights[flight.id] = flight;

    airlineRepository.failingIds.add(10);

    await cubit.load(flight.id);

    final state = cubit.state;

    expect(state.isReady, isTrue);

    expect(state.flight?.id, flight.id);

    expect(state.departureAirport, isNotNull);
    expect(state.arrivalAirport, isNotNull);

    expect(state.airline, isNull);

    expect(airlineRepository.requests[10], 1);
  });

  test('keeps successful airports when another airport fails', () async {
    final flight = makeFlight(id: 'flight-1');

    flightRepository.flights[flight.id] = flight;

    airportRepository.failingIds.add(200);

    await cubit.load(flight.id);

    final state = cubit.state;

    expect(state.isReady, isTrue);

    expect(state.departureAirport?.displayCode, 'LIS');

    expect(state.arrivalAirport, isNull);

    // Airline metadata remains available independently.
    expect(state.airline?.name, 'TAP Air Portugal');
  });

  // -------------------------------------------------------------------------
  // Concurrent requests
  // -------------------------------------------------------------------------

  test('ignores an older flight response', () async {
    final first = Completer<Flight>();
    final second = Completer<Flight>();

    flightRepository.pendingRequests['flight-1'] = first;
    flightRepository.pendingRequests['flight-2'] = second;

    final firstLoad = cubit.load('flight-1');

    await flushAsync();

    expect(cubit.state.isLoading, isTrue);

    final secondLoad = cubit.load('flight-2');

    await flushAsync();

    second.complete(
      makeFlight(
        id: 'flight-2',
        departureAirportId: 300,
        arrivalAirportId: 200,
      ),
    );

    await secondLoad;

    expect(cubit.state.isReady, isTrue);

    expect(cubit.state.flight?.id, 'flight-2');

    first.complete(makeFlight(id: 'flight-1'));

    await firstLoad;

    // The older response must not replace the newer flight.
    expect(cubit.state.flight?.id, 'flight-2');

    expect(cubit.state.departureAirport?.displayCode, 'LHR');
  });

  // -------------------------------------------------------------------------
  // Cubit lifecycle
  // -------------------------------------------------------------------------

  test('does not emit after being closed', () async {
    final pending = Completer<Flight>();

    flightRepository.pendingRequests['flight-1'] = pending;

    final loadFuture = cubit.load('flight-1');

    await flushAsync();

    expect(cubit.state.isLoading, isTrue);

    await cubit.close();

    pending.complete(makeFlight(id: 'flight-1'));

    await loadFuture;

    expect(cubit.isClosed, isTrue);
  });
}
