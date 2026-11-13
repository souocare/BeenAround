import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_associated_flights_section.dart';

import '../fakes/fake_trip_association_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/flights/domain/flight_detail.dart';
import 'package:beenaround/features/flights/domain/flight_timing.dart';

import 'package:beenaround/features/explore/data/countries_repository.dart';

import '../fakes/fake_countries_repository.dart';

const tripId = 'trip-1';

Flight sampleFlight({
  String id = 'flight-1',
  String flightNumber = 'TP1234',
  String departureOn = '2026-10-10',
}) {
  return Flight(
    id: id,
    departureAirportId: 100,
    arrivalAirportId: 200,
    departureOn: departureOn,
    flightNumber: flightNumber,
    status: FlightStatus.flown,
    createdAt: DateTime.utc(2026, 10, 10),
    updatedAt: DateTime.utc(2026, 10, 10),
  );
}

/// Supplies personal flights to the picker without using HTTP.
class FakeSectionFlightRepository extends Fake implements FlightRepository {
  FakeSectionFlightRepository({List<Flight> flights = const []})
    : flights = List.of(flights);

  final List<Flight> flights;

  int getFlightsCalls = 0;

  int getFlightDetailCalls = 0;
  int deleteFlightCalls = 0;

  String? lastRequestedFlightId;
  String? lastDeletedFlightId;

  Future<void> Function(String flightId)? onDeleteFlight;

  @override
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  }) async {
    getFlightsCalls++;

    final filtered = status == null
        ? flights
        : flights.where((flight) => flight.status == status).toList();

    final start = offset.clamp(0, filtered.length);
    final end = (start + limit).clamp(0, filtered.length);

    return FlightPage(
      items: filtered.sublist(start, end),
      total: filtered.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<FlightDetail> getFlightDetail({required String flightId}) async {
    getFlightDetailCalls++;
    lastRequestedFlightId = flightId;

    final flight = flights.where((item) => item.id == flightId).firstOrNull;

    if (flight == null) {
      throw StateError('Flight not found: $flightId');
    }

    return FlightDetail(
      flight: flight,
      timing: const FlightTiming(
        departure: FlightLocalTime(
          status: FlightLocalTimeStatus.valid,
          utcOffsetMinutes: 0,
        ),
        arrival: FlightLocalTime(
          status: FlightLocalTimeStatus.valid,
          utcOffsetMinutes: 0,
        ),
        durationMinutes: null,
      ),
    );
  }

  @override
  Future<void> deleteFlight({required String flightId}) async {
    deleteFlightCalls++;
    lastDeletedFlightId = flightId;

    final index = flights.indexWhere((flight) => flight.id == flightId);

    if (index == -1) {
      throw StateError('Flight not found: $flightId');
    }

    await onDeleteFlight?.call(flightId);

    flights.removeAt(index);
  }
}

/// Catalog failures must not prevent flight association management.
class UnavailableAirportRepository extends Fake implements AirportRepository {
  @override
  Future<Airport> getAirport({required int airportId}) async {
    throw StateError('Airport catalog unavailable.');
  }
}

class UnavailableAirlineRepository extends Fake implements AirlineRepository {
  @override
  Future<Airline> getAirline({required int airlineId}) async {
    throw StateError('Airline catalog unavailable.');
  }
}

class AvailableAirportRepository extends Fake implements AirportRepository {
  @override
  Future<Airport> getAirport({required int airportId}) async {
    if (airportId == 100) {
      return const Airport(
        id: 100,
        ident: 'LPPT',
        iataCode: 'LIS',
        icaoCode: 'LPPT',
        name: 'Humberto Delgado Airport',
        municipality: 'Lisbon',
        countryName: 'Portugal',
        countryCode: 'PT',
        type: 'large_airport',
        scheduledService: true,
      );
    }

    if (airportId == 200) {
      return const Airport(
        id: 200,
        ident: 'LEBL',
        iataCode: 'BCN',
        icaoCode: 'LEBL',
        name: 'Barcelona-El Prat Airport',
        municipality: 'Barcelona',
        countryName: 'Spain',
        countryCode: 'ES',
        type: 'large_airport',
        scheduledService: true,
      );
    }

    throw StateError('Unknown airport.');
  }
}

Widget buildTestApp({
  required FakeTripAssociationRepository associationRepository,
  FlightRepository? flightRepository,
  AirportRepository? airportRepository,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<TripAssociationRepository>.value(
        value: associationRepository,
      ),
      RepositoryProvider<FlightRepository>.value(
        value: flightRepository ?? FakeSectionFlightRepository(),
      ),
      RepositoryProvider<AirportRepository>(
        create: (_) => UnavailableAirportRepository(),
      ),
      RepositoryProvider<AirlineRepository>(
        create: (_) => UnavailableAirlineRepository(),
      ),
      RepositoryProvider<AirportRepository>.value(
        value: airportRepository ?? UnavailableAirportRepository(),
      ),
      RepositoryProvider<CountriesRepository>(
        create: (_) => FakeCountriesRepository(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: BlocProvider<TripAssociationsCubit>(
          create: (context) => TripAssociationsCubit(
            repository: associationRepository,
            tripId: tripId,
          )..load(),
          child: const SingleChildScrollView(
            child: TripAssociatedFlightsSection(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TripAssociatedFlightsSection', () {
    testWidgets('shows empty state and Add action', (tester) async {
      final repository = FakeTripAssociationRepository();

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripAssociatedFlightsSection')),
        findsOneWidget,
      );

      expect(find.text('Flights'), findsOneWidget);

      expect(find.byKey(const Key('tripFlightsCount')), findsOneWidget);

      expect(find.text('0'), findsOneWidget);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      expect(find.byKey(const Key('addTripFlightsButton')), findsOneWidget);
    });

    testWidgets('displays explicitly associated flights', (tester) async {
      final repository = FakeTripAssociationRepository(
        flights: [
          sampleFlight(id: 'flight-1', flightNumber: 'TP1234'),
          sampleFlight(
            id: 'flight-2',
            flightNumber: 'FR5678',
            departureOn: '2026-10-15',
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      expect(find.byKey(const Key('tripFlight-flight-2')), findsOneWidget);

      expect(find.text('TP1234'), findsOneWidget);
      expect(find.text('FR5678'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
      'catalog failure does not hide flights or association actions',
      (tester) async {
        final repository = FakeTripAssociationRepository(
          flights: [sampleFlight()],
        );

        await tester.pumpWidget(
          buildTestApp(associationRepository: repository),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

        expect(find.text('Airport 100 → Airport 200'), findsOneWidget);

        expect(
          find.byKey(const Key('viewTripFlight-flight-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('removeTripFlight-flight-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets('canceling removal preserves the association', (tester) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('removeTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(find.text('Remove flight from Trip?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));

      await tester.pumpAndSettle();

      expect(repository.removeFlightCalls, 0);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);
    });

    testWidgets('removing a flight updates Trip associations', (tester) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('removeTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(
        find.textContaining('The flight will remain available in Explore.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Remove'));

      await tester.pumpAndSettle();

      expect(repository.removeFlightCalls, 1);
      expect(repository.flights, isEmpty);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsNothing);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);
    });

    testWidgets('Add opens the existing flights picker', (tester) async {
      final associationRepository = FakeTripAssociationRepository();

      final flightRepository = FakeSectionFlightRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addTripFlightsButton')));

      await tester.pumpAndSettle();

      expect(find.text('Add flights'), findsOneWidget);

      expect(
        find.byKey(const Key('tripFlightPicker-flight-1')),
        findsOneWidget,
      );

      expect(flightRepository.getFlightsCalls, 1);
    });

    testWidgets('selecting a flight associates it with the Trip', (
      tester,
    ) async {
      final associationRepository = FakeTripAssociationRepository();

      final flightRepository = FakeSectionFlightRepository(
        flights: [sampleFlight()],
      );

      associationRepository.onAddFlight = (receivedTripId, flightId) async {
        expect(receivedTripId, tripId);
        expect(flightId, 'flight-1');

        associationRepository.flights.add(sampleFlight(id: flightId));
      };

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addTripFlightsButton')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tripFlightPicker-flight-1')));

      await tester.pump();

      await tester.tap(find.byKey(const Key('confirmTripFlightSelection')));

      await tester.pumpAndSettle();

      expect(associationRepository.addFlightCalls, 1);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsNothing);
    });

    testWidgets('already-associated flights are excluded from the picker', (
      tester,
    ) async {
      final associationRepository = FakeTripAssociationRepository(
        flights: [sampleFlight(id: 'flight-1')],
      );

      final flightRepository = FakeSectionFlightRepository(
        flights: [
          sampleFlight(id: 'flight-1'),
          sampleFlight(id: 'flight-2'),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addTripFlightsButton')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsNothing);

      expect(
        find.byKey(const Key('tripFlightPicker-flight-2')),
        findsOneWidget,
      );
    });
    testWidgets('opens Flight Details for the selected associated flight', (
      tester,
    ) async {
      final flight = sampleFlight(id: 'flight-1', flightNumber: 'TP1234');

      final associationRepository = FakeTripAssociationRepository(
        flights: [flight],
      );

      final flightRepository = FakeSectionFlightRepository(flights: [flight]);

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('viewTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(find.text('Flight Details'), findsOneWidget);

      expect(find.byKey(const Key('deleteFlightButton')), findsOneWidget);

      expect(flightRepository.getFlightDetailCalls, 1);
      expect(flightRepository.lastRequestedFlightId, 'flight-1');

      expect(flightRepository.deleteFlightCalls, 0);
    });
    testWidgets('returning from Flight Details preserves the association', (
      tester,
    ) async {
      final flight = sampleFlight();

      final associationRepository = FakeTripAssociationRepository(
        flights: [flight],
      );

      final flightRepository = FakeSectionFlightRepository(flights: [flight]);

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('viewTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(find.text('Flight Details'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      expect(associationRepository.flights, hasLength(1));

      expect(flightRepository.deleteFlightCalls, 0);
      expect(associationRepository.removeFlightCalls, 0);
    });
    testWidgets('deleting a Flight from details refreshes Trip associations', (
      tester,
    ) async {
      final flight = sampleFlight();

      final associationRepository = FakeTripAssociationRepository(
        flights: [flight],
      );

      final flightRepository = FakeSectionFlightRepository(flights: [flight]);

      // Simulate the backend's ON DELETE CASCADE behavior:
      // deleting a Flight removes its Trip associations.
      flightRepository.onDeleteFlight = (flightId) async {
        associationRepository.flights.removeWhere(
          (item) => item.id == flightId,
        );
      };

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      // Open the associated Flight.
      await tester.tap(find.byKey(const Key('viewTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(find.text('Flight Details'), findsOneWidget);

      // Request global deletion.
      await tester.tap(find.byKey(const Key('deleteFlightButton')));

      await tester.pumpAndSettle();

      expect(find.text('Delete flight?'), findsOneWidget);

      expect(find.textContaining('permanently removed'), findsOneWidget);

      // Confirm global deletion.
      await tester.tap(find.text('Delete Flight'));

      await tester.pumpAndSettle();

      // The Flight was deleted globally.
      expect(flightRepository.deleteFlightCalls, 1);
      expect(flightRepository.lastDeletedFlightId, 'flight-1');

      expect(flightRepository.flights, isEmpty);

      // The associated Flight disappears after returning to the Trip.
      expect(find.text('Flight Details'), findsNothing);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsNothing);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      // No explicit "remove from Trip" request was necessary.
      expect(associationRepository.removeFlightCalls, 0);
    });
  });
  testWidgets('shows IATA airport codes when catalog is available', (
    tester,
  ) async {
    final repository = FakeTripAssociationRepository(flights: [sampleFlight()]);

    await tester.pumpWidget(
      buildTestApp(
        associationRepository: repository,
        airportRepository: AvailableAirportRepository(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('LIS → BCN'), findsOneWidget);

    expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);
  });
}
