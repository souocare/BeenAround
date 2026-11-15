import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/explore/data/countries_repository.dart';

import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_detail.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:beenaround/features/flights/domain/flight_timing.dart';

import 'package:beenaround/features/trips/application/trip_associations_cubit.dart';
import 'package:beenaround/features/trips/domain/trip_association_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_associated_flights_section.dart';

import '../fakes/fake_countries_repository.dart';
import '../fakes/fake_trip_association_repository.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/flights/presentation/widgets/flight_card.dart';

const tripId = 'trip-1';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Flight repository
// ---------------------------------------------------------------------------

/// Supplies personal flights without using HTTP.
class FakeSectionFlightRepository extends Fake implements FlightRepository {
  FakeSectionFlightRepository({List<Flight> flights = const []})
    : flights = List.of(flights);

  final List<Flight> flights;

  int getFlightsCalls = 0;
  int getFlightDetailCalls = 0;
  int deleteFlightCalls = 0;

  String? lastRequestedFlightId;
  String? lastDeletedFlightId;

  int createFlightCalls = 0;

  FlightCreateInput? lastCreateInput;

  Future<Flight> Function(FlightCreateInput input)? onCreateFlight;

  @override
  Future<Flight> createFlight({required FlightCreateInput input}) async {
    createFlightCalls++;
    lastCreateInput = input;

    final createdFlight = onCreateFlight != null
        ? await onCreateFlight!(input)
        : sampleFlight(id: 'created-flight-1');

    flights.add(createdFlight);

    return createdFlight;
  }

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

// ---------------------------------------------------------------------------
// Aviation catalog repositories
// ---------------------------------------------------------------------------

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

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    const airports = [
      Airport(
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
      ),
      Airport(
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
      ),
    ];

    final normalizedQuery = query?.trim().toLowerCase();

    final matches = airports.where((airport) {
      if (countryCode != null && airport.countryCode != countryCode) {
        return false;
      }

      if (scheduledOnly && !airport.scheduledService) {
        return false;
      }

      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        return airport.displayCode.toLowerCase().contains(normalizedQuery) ||
            airport.name.toLowerCase().contains(normalizedQuery) ||
            (airport.municipality?.toLowerCase().contains(normalizedQuery) ??
                false);
      }

      return true;
    }).toList();

    return AirportPage(
      items: matches.skip(offset).take(limit).toList(),
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }
}

class FlightCreationCountriesRepository extends Fake
    implements CountriesRepository {
  @override
  Future<List<Country>> getCountries() async {
    return const [
      Country(
        code: 'PT',
        name: 'Portugal',
        alpha3Code: 'PRT',
        continent: 'Europe',
      ),
      Country(
        code: 'ES',
        name: 'Spain',
        alpha3Code: 'ESP',
        continent: 'Europe',
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Test application
// ---------------------------------------------------------------------------

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
      RepositoryProvider<AirportRepository>.value(
        value: airportRepository ?? UnavailableAirportRepository(),
      ),
      RepositoryProvider<AirlineRepository>(
        create: (_) => UnavailableAirlineRepository(),
      ),
      RepositoryProvider<CountriesRepository>(
        create: (_) => FlightCreationCountriesRepository(),
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

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Opens the Add menu and selects the existing flights option.
///
/// The same flow is reused by all tests that need the Flight Picker.
Future<void> openExistingFlightsPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addTripFlightsButton')));

  await tester.pumpAndSettle();

  expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);
}

Future<void> openCreateFlightForm(WidgetTester tester) async {
  await openExistingFlightsPicker(tester);

  await tester.tap(find.byKey(const Key('createFlightFromPickerButton')));

  await tester.pumpAndSettle();

  expect(find.text('Add Flight'), findsOneWidget);

  expect(find.byKey(const Key('saveFlightButton')), findsOneWidget);
}

Future<void> selectFlightAirport(
  WidgetTester tester, {
  required String fieldKey,
  required String countryCode,
  required int airportId,
}) async {
  final field = find.byKey(Key(fieldKey));

  await tester.ensureVisible(field);
  await tester.pumpAndSettle();

  await tester.tap(field);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(ValueKey('airport-country-$countryCode')));

  await tester.pumpAndSettle();

  await tester.tap(find.byKey(ValueKey('airport-$airportId')));

  await tester.pumpAndSettle();
}

Future<void> createTestFlight(WidgetTester tester) async {
  await openCreateFlightForm(tester);

  await selectFlightAirport(
    tester,
    fieldKey: 'departureAirportField',
    countryCode: 'PT',
    airportId: 100,
  );

  await selectFlightAirport(
    tester,
    fieldKey: 'arrivalAirportField',
    countryCode: 'ES',
    airportId: 200,
  );

  final saveButton = find.byKey(const Key('saveFlightButton'));

  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();

  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

class DelayedFlightAssociationsRepository
    extends FakeTripAssociationRepository {
  DelayedFlightAssociationsRepository({super.flights});

  Completer<void>? delayNextFlightLoad;

  @override
  Future<List<Flight>> getFlights({required String tripId}) async {
    final delay = delayNextFlightLoad;

    if (delay != null) {
      delayNextFlightLoad = null;
      await delay.future;
    }

    return super.getFlights(tripId: tripId);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TripAssociatedFlightsSection', () {
    // -----------------------------------------------------------------------
    // Empty state
    // -----------------------------------------------------------------------

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
      expect(find.text('No flights added'), findsOneWidget);

      expect(find.text('Add flights'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Add menu - NEW
    // -----------------------------------------------------------------------

    testWidgets('Add opens the Flight Picker directly with a create action', (
      tester,
    ) async {
      final associationRepository = FakeTripAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(associationRepository: associationRepository),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addTripFlightsButton')));

      await tester.pumpAndSettle();

      // The picker opens directly.
      expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);

      // Creating a new flight is available inside the picker.
      expect(
        find.byKey(const Key('createFlightFromPickerButton')),
        findsOneWidget,
      );

      // The old popup menu must not exist.
      expect(find.byKey(const Key('addExistingFlightsOption')), findsNothing);

      expect(find.byKey(const Key('createNewFlightOption')), findsNothing);

      // Opening the picker does not associate anything.
      expect(associationRepository.addFlightCalls, 0);

      // Cancel without selecting anything.
      await tester.tap(find.text('Cancel'));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlightPickerSearch')), findsNothing);

      expect(associationRepository.addFlightCalls, 0);
    });

    // -----------------------------------------------------------------------
    // Flight list
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Catalog fallback
    // -----------------------------------------------------------------------

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

        final flightCard = find.byKey(const ValueKey('flight-card-flight-1'));

        expect(flightCard, findsOneWidget);

        expect(
          find.descendant(of: flightCard, matching: find.text('100')),
          findsOneWidget,
        );

        expect(
          find.descendant(of: flightCard, matching: find.text('200')),
          findsOneWidget,
        );

        expect(
          find.descendant(
            of: flightCard,
            matching: find.text('Unknown airport'),
          ),
          findsNWidgets(2),
        );

        // Catalog failures must not hide Trip association actions.
        expect(
          find.byKey(const Key('viewTripFlight-flight-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('removeTripFlight-flight-1')),
          findsOneWidget,
        );

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

    // -----------------------------------------------------------------------
    // Cancel removal
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Remove association
    // -----------------------------------------------------------------------

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

      final confirmationDialog = find.byType(AlertDialog);

      expect(confirmationDialog, findsOneWidget);

      final confirmRemoveButton = find.descendant(
        of: confirmationDialog,
        matching: find.widgetWithText(TextButton, 'Remove'),
      );

      expect(confirmRemoveButton, findsOneWidget);

      await tester.tap(confirmRemoveButton);
      await tester.pumpAndSettle();

      await tester.pumpAndSettle();

      expect(repository.removeFlightCalls, 1);

      expect(repository.flights, isEmpty);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsNothing);
      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      expect(find.byKey(const Key('addTripFlightsButton')), findsOneWidget);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Existing flights picker - UPDATED
    // -----------------------------------------------------------------------

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

      // Open Add menu and select "Add existing flights".
      await openExistingFlightsPicker(tester);

      expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);

      expect(
        find.byKey(const Key('tripFlightPicker-flight-1')),
        findsOneWidget,
      );

      expect(flightRepository.getFlightsCalls, 1);
    });

    // -----------------------------------------------------------------------
    // Add existing flight - UPDATED
    // -----------------------------------------------------------------------

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

      // Open existing flights picker through the Add menu.
      await openExistingFlightsPicker(tester);

      await tester.tap(find.byKey(const Key('tripFlightPicker-flight-1')));

      await tester.pump();

      await tester.tap(find.byKey(const Key('confirmTripFlightSelection')));

      await tester.pumpAndSettle();

      expect(associationRepository.addFlightCalls, 1);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Exclude already associated flights - UPDATED
    // -----------------------------------------------------------------------

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

      // Open existing flights picker through the Add menu.
      await openExistingFlightsPicker(tester);

      expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsNothing);

      expect(
        find.byKey(const Key('tripFlightPicker-flight-2')),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // Flight Details navigation
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Return from Flight Details
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // Global Flight deletion
    // -----------------------------------------------------------------------

    testWidgets('deleting a Flight from details refreshes Trip associations', (
      tester,
    ) async {
      final flight = sampleFlight();

      final associationRepository = FakeTripAssociationRepository(
        flights: [flight],
      );

      final flightRepository = FakeSectionFlightRepository(flights: [flight]);

      // Simulate backend cascade deletion:
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

      // Open Flight Details.
      await tester.tap(find.byKey(const Key('viewTripFlight-flight-1')));

      await tester.pumpAndSettle();

      expect(find.text('Flight Details'), findsOneWidget);

      // Request global deletion.
      await tester.tap(find.byKey(const Key('deleteFlightButton')));

      await tester.pumpAndSettle();

      expect(find.text('Delete flight?'), findsOneWidget);

      expect(find.textContaining('permanently removed'), findsOneWidget);

      // Confirm deletion.
      await tester.tap(find.text('Delete Flight'));

      await tester.pumpAndSettle();

      // Flight was deleted globally.
      expect(flightRepository.deleteFlightCalls, 1);

      expect(flightRepository.lastDeletedFlightId, 'flight-1');

      expect(flightRepository.flights, isEmpty);

      // The Trip association disappears after refresh.
      expect(find.text('Flight Details'), findsNothing);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsNothing);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      // No explicit "Remove from Trip" request was made.
      expect(associationRepository.removeFlightCalls, 0);
    });

    // -----------------------------------------------------------------------
    // IATA codes
    // -----------------------------------------------------------------------

    testWidgets('shows IATA airport codes when catalog is available', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: repository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      final flightCard = find.byKey(const ValueKey('flight-card-flight-1'));

      expect(flightCard, findsOneWidget);

      expect(
        find.descendant(of: flightCard, matching: find.text('LIS')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: flightCard, matching: find.text('BCN')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('tripFlight-flight-1')), findsOneWidget);
    });
    testWidgets('Flight Picker works on narrow mobile screens', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(associationRepository: FakeTripAssociationRepository()),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addTripFlightsButton')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);

      expect(
        find.byKey(const Key('createFlightFromPickerButton')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('confirmTripFlightSelection')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
    testWidgets('Create new flight opens the form from the picker', (
      tester,
    ) async {
      final associationRepository = FakeTripAssociationRepository();
      final flightRepository = FakeSectionFlightRepository();

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      await openCreateFlightForm(tester);

      expect(find.text('Add Flight'), findsOneWidget);

      expect(find.byKey(const Key('saveFlightButton')), findsOneWidget);

      // Opening the form must not create or associate anything.
      expect(flightRepository.createFlightCalls, 0);
      expect(associationRepository.addFlightCalls, 0);
      expect(associationRepository.flights, isEmpty);
    });
    testWidgets(
      'canceling flight creation returns to picker without creating anything',
      (tester) async {
        final associationRepository = FakeTripAssociationRepository();
        final flightRepository = FakeSectionFlightRepository();

        await tester.pumpWidget(
          buildTestApp(
            associationRepository: associationRepository,
            flightRepository: flightRepository,
            airportRepository: AvailableAirportRepository(),
          ),
        );

        await tester.pumpAndSettle();

        await openCreateFlightForm(tester);

        // Cancel the creation form.
        await tester.tap(find.byTooltip('Close'));

        await tester.pumpAndSettle();

        // The form closes.
        expect(find.text('Add Flight'), findsNothing);

        // The picker remains open.
        expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);

        expect(
          find.byKey(const Key('createFlightFromPickerButton')),
          findsOneWidget,
        );

        // No Flight was created.
        expect(flightRepository.createFlightCalls, 0);
        expect(flightRepository.flights, isEmpty);

        // No association was created.
        expect(associationRepository.addFlightCalls, 0);
        expect(associationRepository.flights, isEmpty);

        // Cancel the picker too.
        await tester.tap(find.text('Cancel'));

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tripFlightPickerSearch')), findsNothing);

        expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);
      },
    );
    testWidgets(
      'creating a flight and canceling the picker preserves an independent flight',
      (tester) async {
        final associationRepository = FakeTripAssociationRepository();
        final flightRepository = FakeSectionFlightRepository();

        await tester.pumpWidget(
          buildTestApp(
            associationRepository: associationRepository,
            flightRepository: flightRepository,
            airportRepository: AvailableAirportRepository(),
          ),
        );

        await tester.pumpAndSettle();

        await createTestFlight(tester);

        // Flight was persisted independently.
        expect(flightRepository.createFlightCalls, 1);
        expect(flightRepository.flights, hasLength(1));
        expect(flightRepository.flights.single.id, 'created-flight-1');

        // After creation, the user returns to the picker.
        expect(find.byKey(const Key('tripFlightPickerSearch')), findsOneWidget);

        expect(find.text('Add Flight'), findsNothing);

        // The newly created Flight is visible.
        final createdFlightFinder = find.byKey(
          const Key('tripFlightPicker-created-flight-1'),
        );

        expect(createdFlightFinder, findsOneWidget);

        // It is automatically selected.
        final tile = tester.widget<CheckboxListTile>(createdFlightFinder);

        expect(tile.value, isTrue);

        // But it has not been associated with the Trip.
        expect(associationRepository.addFlightCalls, 0);

        // Cancel the picker.
        await tester.tap(find.text('Cancel'));

        await tester.pumpAndSettle();

        // The picker closes.
        expect(find.byKey(const Key('tripFlightPickerSearch')), findsNothing);

        // The Flight remains globally persisted.
        expect(flightRepository.flights, hasLength(1));
        expect(flightRepository.flights.single.id, 'created-flight-1');

        // No association was created.
        expect(associationRepository.addFlightCalls, 0);
        expect(associationRepository.flights, isEmpty);

        expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);
      },
    );
    testWidgets(
      'creating a flight auto-selects it and confirms association only on Add',
      (tester) async {
        final associationRepository = FakeTripAssociationRepository();
        final flightRepository = FakeSectionFlightRepository();

        associationRepository.onAddFlight = (receivedTripId, flightId) async {
          expect(receivedTripId, tripId);
          expect(flightId, 'created-flight-1');

          final createdFlight = flightRepository.flights.singleWhere(
            (flight) => flight.id == flightId,
          );

          associationRepository.flights.add(createdFlight);
        };

        await tester.pumpWidget(
          buildTestApp(
            associationRepository: associationRepository,
            flightRepository: flightRepository,
            airportRepository: AvailableAirportRepository(),
          ),
        );

        await tester.pumpAndSettle();

        await createTestFlight(tester);

        expect(flightRepository.createFlightCalls, 1);

        // The created Flight is automatically selected.
        final tile = tester.widget<CheckboxListTile>(
          find.byKey(const Key('tripFlightPicker-created-flight-1')),
        );

        expect(tile.value, isTrue);

        // No association exists before confirmation.
        expect(associationRepository.addFlightCalls, 0);

        expect(associationRepository.flights, isEmpty);

        // Explicit confirmation.
        await tester.tap(find.byKey(const Key('confirmTripFlightSelection')));

        await tester.pumpAndSettle();

        // The Flight remains independently persisted.
        expect(flightRepository.flights, hasLength(1));

        // The association was created only after confirmation.
        expect(associationRepository.addFlightCalls, 1);

        expect(associationRepository.flights, hasLength(1));

        expect(associationRepository.flights.single.id, 'created-flight-1');

        // Trip Details now displays the Flight.
        expect(
          find.byKey(const Key('tripFlight-created-flight-1')),
          findsOneWidget,
        );

        expect(find.byKey(const Key('tripFlightsEmptyState')), findsNothing);
      },
    );
    testWidgets(
      'association failure after picker confirmation preserves created flight',
      (tester) async {
        final associationRepository = FakeTripAssociationRepository();
        final flightRepository = FakeSectionFlightRepository();

        associationRepository.onAddFlight = (receivedTripId, flightId) async {
          expect(receivedTripId, tripId);
          expect(flightId, 'created-flight-1');

          throw StateError('Simulated association failure');
        };

        await tester.pumpWidget(
          buildTestApp(
            associationRepository: associationRepository,
            flightRepository: flightRepository,
            airportRepository: AvailableAirportRepository(),
          ),
        );

        await tester.pumpAndSettle();

        await createTestFlight(tester);

        expect(flightRepository.createFlightCalls, 1);

        expect(flightRepository.flights, hasLength(1));

        // No association before confirmation.
        expect(associationRepository.addFlightCalls, 0);

        // Explicitly attempt association.
        await tester.tap(find.byKey(const Key('confirmTripFlightSelection')));

        await tester.pumpAndSettle();

        // Association was attempted.
        expect(associationRepository.addFlightCalls, 1);

        // The Trip did not receive the Flight.
        expect(associationRepository.flights, isEmpty);

        // The Flight still exists globally.
        expect(flightRepository.flights, hasLength(1));

        expect(flightRepository.flights.single.id, 'created-flight-1');

        // No global deletion occurred.
        expect(flightRepository.deleteFlightCalls, 0);

        expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);
      },
    );
    testWidgets('newly created flight is highlighted as NEW in the picker', (
      tester,
    ) async {
      final associationRepository = FakeTripAssociationRepository();
      final flightRepository = FakeSectionFlightRepository();

      await tester.pumpWidget(
        buildTestApp(
          associationRepository: associationRepository,
          flightRepository: flightRepository,
          airportRepository: AvailableAirportRepository(),
        ),
      );

      await tester.pumpAndSettle();

      await createTestFlight(tester);

      expect(
        find.byKey(const Key('tripFlightPicker-created-flight-1')),
        findsOneWidget,
      );

      expect(find.text('NEW'), findsOneWidget);

      expect(associationRepository.addFlightCalls, 0);
    });
    testWidgets('renders associated flights using the shared FlightCard', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final tripFlight = find.byKey(const Key('tripFlight-flight-1'));

      expect(tripFlight, findsOneWidget);

      // The exact widget used by Flight History.
      expect(
        find.descendant(of: tripFlight, matching: find.byType(FlightCard)),
        findsOneWidget,
      );

      // The FlightCard preserves its existing identity.
      expect(
        find.byKey(const ValueKey('flight-card-flight-1')),
        findsOneWidget,
      );

      // Trip-specific actions are outside FlightCard.
      expect(find.byKey(const Key('viewTripFlight-flight-1')), findsOneWidget);

      expect(
        find.byKey(const Key('removeTripFlight-flight-1')),
        findsOneWidget,
      );

      final sharedCard = find.byType(FlightCard);

      expect(
        find.descendant(
          of: sharedCard,
          matching: find.byKey(const Key('removeTripFlight-flight-1')),
        ),
        findsNothing,
      );

      expect(tester.takeException(), isNull);
    });
    testWidgets('shared FlightCard preserves flight number and status', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight(id: 'flight-1', flightNumber: 'TP1234')],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final card = find.byType(FlightCard);

      expect(card, findsOneWidget);

      expect(
        find.descendant(of: card, matching: find.text('TP1234')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: card, matching: find.text('Completed')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
    testWidgets('shows exactly one Add Flights action when empty', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('addTripFlightsButton'));

      expect(addButton, findsOneWidget);

      final button = tester.widget<ButtonStyleButton>(addButton);

      expect(button.onPressed, isNotNull);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
    testWidgets('shows header add action when associated flights exist', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      // The shared FlightCard is displayed.
      expect(
        find.byKey(const ValueKey('flight-card-flight-1')),
        findsOneWidget,
      );

      // The empty state disappears.
      expect(find.byKey(const Key('tripFlightsEmptyState')), findsNothing);

      // There is still exactly one Add action.
      final addButton = find.byKey(const Key('addTripFlightsButton'));

      expect(addButton, findsOneWidget);

      final button = tester.widget<TextButton>(addButton);

      expect(button.onPressed, isNotNull);

      expect(tester.takeException(), isNull);
    });
    testWidgets('disables Add Flights while associations are refreshing', (
      tester,
    ) async {
      final repository = DelayedFlightAssociationsRepository();

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final sectionContext = tester.element(
        find.byType(TripAssociatedFlightsSection),
      );

      final cubit = sectionContext.read<TripAssociationsCubit>();

      final delay = Completer<void>();
      repository.delayNextFlightLoad = delay;

      final refresh = cubit.refresh();

      expect(cubit.state.isRefreshing, isTrue);

      // Allow BlocBuilder to rebuild while the refresh is still pending.

      // Do not use pumpAndSettle() before completing the delayed request.

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 16));

      final addButtonFinder = find.byKey(const Key('addTripFlightsButton'));

      expect(addButtonFinder, findsOneWidget);

      final addButton = tester.widget<FilledButton>(addButtonFinder);

      expect(
        addButton.onPressed,

        isNull,

        reason: 'Add Flights must be disabled during refresh.',
      );

      delay.complete();

      await refresh;
      await tester.pumpAndSettle();

      expect(cubit.state.isRefreshing, isFalse);

      final restoredButton = tester.widget<FilledButton>(
        find.byKey(const Key('addTripFlightsButton')),
      );

      expect(restoredButton.onPressed, isNotNull);

      expect(tester.takeException(), isNull);
    });
    testWidgets('disables Flight actions while removing an association', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      final removalDelay = Completer<void>();

      repository.onRemoveFlight = (tripId, flightId) async {
        await removalDelay.future;

        repository.flights.removeWhere((flight) => flight.id == flightId);
      };

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('removeTripFlight-flight-1')));

      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);

      expect(dialog, findsOneWidget);

      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'Remove'),
        ),
      );

      await tester.pump();

      final cubit = tester
          .element(find.byType(TripAssociatedFlightsSection))
          .read<TripAssociationsCubit>();

      expect(cubit.state.isMutating, isTrue);

      final addButton = tester.widget<TextButton>(
        find.byKey(const Key('addTripFlightsButton')),
      );

      final removeButton = tester.widget<TextButton>(
        find.byKey(const Key('removeTripFlight-flight-1')),
      );

      expect(addButton.onPressed, isNull);
      expect(removeButton.onPressed, isNull);

      removalDelay.complete();

      await tester.pumpAndSettle();

      expect(cubit.state.isMutating, isFalse);

      expect(find.byKey(const Key('tripFlight-flight-1')), findsNothing);

      expect(find.byKey(const Key('tripFlightsEmptyState')), findsOneWidget);

      final restoredButton = tester.widget<FilledButton>(
        find.byKey(const Key('addTripFlightsButton')),
      );

      expect(restoredButton.onPressed, isNotNull);

      expect(tester.takeException(), isNull);
    });
    testWidgets('associated flight exposes an accessible navigation label', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final flightCard = find.byKey(const ValueKey('flight-card-flight-1'));

      expect(flightCard, findsOneWidget);

      final semantics = find.ancestor(
        of: find.byKey(const Key('openTripFlight-flight-1')),
        matching: find.byType(Semantics),
      );

      expect(semantics, findsWidgets);

      final labelledSemantics = tester
          .widgetList<Semantics>(semantics)
          .where(
            (widget) =>
                widget.properties.label?.contains('View Flight TP1234') ??
                false,
          );

      expect(labelledSemantics, isNotEmpty);

      expect(tester.takeException(), isNull);
    });
    testWidgets('Remove Flight action identifies the flight', (tester) async {
      final repository = FakeTripAssociationRepository(
        flights: [sampleFlight()],
      );

      await tester.pumpWidget(buildTestApp(associationRepository: repository));

      await tester.pumpAndSettle();

      final removeButton = find.byKey(const Key('removeTripFlight-flight-1'));

      final tooltip = find.ancestor(
        of: removeButton,
        matching: find.byType(Tooltip),
      );

      expect(tooltip, findsOneWidget);

      final widget = tester.widget<Tooltip>(tooltip);

      expect(widget.message, contains('TP1234'));
      expect(widget.message, contains('from Trip'));

      expect(tester.takeException(), isNull);
    });
  });
}
