import 'dart:async';

import 'package:beenaround/features/flights/application/delete_flight_cubit.dart';
import 'package:beenaround/features/flights/application/flight_catalog_resolver.dart';
import 'package:beenaround/features/flights/application/flight_details_cubit.dart';

import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_detail.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:beenaround/features/flights/domain/flight_timing.dart';

import 'package:beenaround/features/flights/presentation/pages/flight_details_page.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Flight repository
// ---------------------------------------------------------------------------

class _FlightRepository extends Fake implements FlightRepository {
  int detailCalls = 0;
  int deleteCalls = 0;

  String? deletedFlightId;

  Completer<void>? pendingDeletion;

  bool shouldFailDeletion = false;

  final flight = Flight(
    id: 'flight-1',
    departureAirportId: 100,
    arrivalAirportId: 200,
    departureOn: '2026-10-10',
    departureTime: '19:20',
    arrivalOn: '2026-10-10',
    arrivalTime: '22:15',
    status: FlightStatus.flown,
    flightNumber: 'TP1019',
    createdAt: DateTime.utc(2026, 10, 10),
    updatedAt: DateTime.utc(2026, 10, 10),
  );

  @override
  Future<FlightDetail> getFlightDetail({required String flightId}) async {
    detailCalls++;

    if (flightId != flight.id) {
      throw StateError('Flight not found');
    }

    return FlightDetail(
      flight: flight,
      timing: const FlightTiming(
        departure: FlightLocalTime(
          status: FlightLocalTimeStatus.valid,
          utcOffsetMinutes: 60,
        ),
        arrival: FlightLocalTime(
          status: FlightLocalTimeStatus.valid,
          utcOffsetMinutes: 120,
        ),
        durationMinutes: 115,
      ),
    );
  }

  @override
  Future<void> deleteFlight({required String flightId}) async {
    deleteCalls++;
    deletedFlightId = flightId;

    final pending = pendingDeletion;

    if (pending != null) {
      await pending.future;
    }

    if (shouldFailDeletion) {
      throw StateError('Simulated deletion failure');
    }
  }
}

// ---------------------------------------------------------------------------
// Aviation catalog repositories
// ---------------------------------------------------------------------------

class _AirportRepository extends Fake implements AirportRepository {
  bool failRequests = false;

  @override
  Future<Airport> getAirport({required int airportId}) async {
    if (failRequests) {
      throw StateError('Airport catalog unavailable');
    }

    return Airport(
      id: airportId,
      ident: 'TEST$airportId',
      iataCode: airportId == 100 ? 'LIS' : 'BCN',
      name: airportId == 100 ? 'Lisbon Airport' : 'Barcelona Airport',
      type: 'large_airport',
      scheduledService: true,
    );
  }
}

class _AirlineRepository extends Fake implements AirlineRepository {
  @override
  Future<Airline> getAirline({required int airlineId}) async {
    throw StateError('Airline unavailable');
  }
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

void main() {
  late _FlightRepository flightRepository;
  late _AirportRepository airportRepository;
  late _AirlineRepository airlineRepository;

  bool? navigationResult;

  setUp(() {
    flightRepository = _FlightRepository();
    airportRepository = _AirportRepository();
    airlineRepository = _AirlineRepository();

    navigationResult = null;
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  key: const Key('openDetailsButton'),
                  onPressed: () async {
                    final resolver = FlightCatalogResolver(
                      airportRepository: airportRepository,
                      airlineRepository: airlineRepository,
                    );

                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) {
                          return MultiBlocProvider(
                            providers: [
                              BlocProvider<FlightDetailsCubit>(
                                create: (_) => FlightDetailsCubit(
                                  repository: flightRepository,
                                  catalogResolver: resolver,
                                )..load('flight-1'),
                              ),
                              BlocProvider<DeleteFlightCubit>(
                                create: (_) => DeleteFlightCubit(
                                  repository: flightRepository,
                                ),
                              ),
                            ],
                            child: const FlightDetailsPage(
                              flightId: 'flight-1',
                            ),
                          );
                        },
                      ),
                    );

                    navigationResult = result;
                  },
                  child: const Text('Open Flight Details'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('openDetailsButton')));

    await tester.pumpAndSettle();

    expect(find.text('Flight Details'), findsOneWidget);

    expect(find.byKey(const Key('deleteFlightButton')), findsOneWidget);
  }

  Future<void> openDeleteConfirmation(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('deleteFlightButton')));

    await tester.pumpAndSettle();

    expect(find.text('Delete flight?'), findsOneWidget);
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.text('Delete Flight'));

    // Do not use pumpAndSettle here:
    // a pending DELETE displays an indeterminate progress indicator.
    await tester.pump();
    await tester.pump();
  }

  tearDown(() {
    final pending = flightRepository.pendingDeletion;

    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  });

  // -------------------------------------------------------------------------
  // Presentation
  // -------------------------------------------------------------------------

  testWidgets('shows the delete button in Flight Details', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    final button = tester.widget<IconButton>(
      find.byKey(const Key('deleteFlightButton')),
    );

    expect(button.onPressed, isNotNull);
    expect(flightRepository.deleteCalls, 0);
  });

  testWidgets('opens confirmation before deleting', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);

    expect(find.textContaining('permanently removed'), findsOneWidget);

    expect(find.text('Cancel'), findsOneWidget);

    expect(flightRepository.deleteCalls, 0);
  });

  testWidgets('uses Cupertino confirmation on iOS', (tester) async {
    await pumpApp(tester, platform: TargetPlatform.iOS);

    await openDetails(tester);
    await openDeleteConfirmation(tester);

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);

    expect(find.byType(AlertDialog), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Cancellation
  // -------------------------------------------------------------------------

  testWidgets('cancelling does not call DELETE', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 0);

    expect(find.text('Flight Details'), findsOneWidget);

    expect(navigationResult, isNull);
  });

  // -------------------------------------------------------------------------
  // Success
  // -------------------------------------------------------------------------

  testWidgets('successful deletion closes details with true', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);

    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 1);

    expect(flightRepository.deletedFlightId, 'flight-1');

    expect(navigationResult, isTrue);

    expect(find.text('Flight Details'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Pending deletion
  // -------------------------------------------------------------------------

  testWidgets('blocks actions while deletion is pending', (tester) async {
    flightRepository.pendingDeletion = Completer<void>();

    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);

    expect(flightRepository.deleteCalls, 1);

    final editButton = tester.widget<IconButton>(
      find.byKey(const Key('editFlightButton')),
    );

    final deleteButton = tester.widget<IconButton>(
      find.byKey(const Key('deleteFlightButton')),
    );

    expect(editButton.onPressed, isNull);
    expect(deleteButton.onPressed, isNull);

    // Attempt to navigate back while the DELETE is pending.
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Flight Details'), findsOneWidget);

    expect(navigationResult, isNull);

    flightRepository.pendingDeletion!.complete();

    await tester.pumpAndSettle();

    expect(navigationResult, isTrue);
    expect(flightRepository.deleteCalls, 1);
  });

  // -------------------------------------------------------------------------
  // Failure
  // -------------------------------------------------------------------------

  testWidgets('failed deletion keeps details open', (tester) async {
    flightRepository.shouldFailDeletion = true;

    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);

    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 1);

    expect(find.text('Flight Details'), findsOneWidget);

    expect(find.text('Unable to delete your flight.'), findsOneWidget);

    expect(navigationResult, isNull);
  });

  testWidgets('allows retry after failed deletion', (tester) async {
    flightRepository.shouldFailDeletion = true;

    await pumpApp(tester);
    await openDetails(tester);

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 1);

    flightRepository.shouldFailDeletion = false;

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 2);
    expect(navigationResult, isTrue);
  });

  // -------------------------------------------------------------------------
  // Missing catalog metadata
  // -------------------------------------------------------------------------

  testWidgets('can delete when airport metadata is unavailable', (
    tester,
  ) async {
    airportRepository.failRequests = true;

    await pumpApp(tester);
    await openDetails(tester);

    final editButton = tester.widget<IconButton>(
      find.byKey(const Key('editFlightButton')),
    );

    final deleteButton = tester.widget<IconButton>(
      find.byKey(const Key('deleteFlightButton')),
    );

    // Editing requires valid catalog metadata.
    expect(editButton.onPressed, isNull);

    // Deleting only requires the loaded flight ID.
    expect(deleteButton.onPressed, isNotNull);

    await openDeleteConfirmation(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();

    expect(flightRepository.deleteCalls, 1);
    expect(navigationResult, isTrue);
  });
}
