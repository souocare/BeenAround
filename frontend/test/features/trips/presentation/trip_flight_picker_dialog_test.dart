import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';

import 'package:beenaround/features/trips/presentation/widgets/trip_flight_picker_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePickerFlightRepository extends Fake implements FlightRepository {
  FakePickerFlightRepository(this.flights);

  final List<Flight> flights;

  int loadCalls = 0;
  bool failNextLoad = false;

  @override
  Future<FlightPage> getFlights({
    int limit = 20,
    int offset = 0,
    FlightStatus? status,
  }) async {
    loadCalls++;
    if (failNextLoad) {
      failNextLoad = false;

      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Unable to retrieve flights.',
        statusCode: 500,
      );
    }

    final end = (offset + limit).clamp(0, flights.length);

    final items = offset >= flights.length
        ? <Flight>[]
        : flights.sublist(offset, end);

    return FlightPage(
      items: items,
      total: flights.length,
      limit: limit,
      offset: offset,
    );
  }
}

class FakePickerAirportRepository extends Fake implements AirportRepository {
  @override
  Future<Airport> getAirport({required int airportId}) async {
    throw StateError('Airport unavailable in test.');
  }
}

class FakePickerAirlineRepository extends Fake implements AirlineRepository {
  @override
  Future<Airline> getAirline({required int airlineId}) async {
    throw StateError('Airline unavailable in test.');
  }
}

Flight sampleFlight({
  required String id,
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

Widget buildTestApp({
  required FlightRepository flightRepository,
  required AirportRepository airportRepository,
  required AirlineRepository airlineRepository,
  Set<String> excludedFlightIds = const {},
  ValueChanged<List<String>?>? onSelection,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FlightRepository>.value(value: flightRepository),
      RepositoryProvider<AirportRepository>.value(value: airportRepository),
      RepositoryProvider<AirlineRepository>.value(value: airlineRepository),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                key: const Key('openTripFlightPicker'),
                onPressed: () async {
                  final selectedIds = await showTripFlightPicker(
                    context: context,
                    excludedFlightIds: excludedFlightIds,
                  );

                  onSelection?.call(selectedIds);
                },
                child: const Text('Open picker'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens the flight picker', (tester) async {
    final flights = [sampleFlight(id: 'flight-1')];

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(find.text('Add flights'), findsOneWidget);

    expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsOneWidget);
  });
  testWidgets('excludes flights already associated with the Trip', (
    tester,
  ) async {
    final flights = [
      sampleFlight(id: 'flight-1'),
      sampleFlight(id: 'flight-2'),
    ];

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
        excludedFlightIds: {'flight-1'},
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsNothing);

    expect(find.byKey(const Key('tripFlightPicker-flight-2')), findsOneWidget);
  });
  testWidgets('filters loaded flights by flight number', (tester) async {
    final flights = [
      sampleFlight(id: 'flight-1', flightNumber: 'TP1234'),
      sampleFlight(id: 'flight-2', flightNumber: 'FR5678'),
    ];

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripFlightPickerSearch')),
      'FR5678',
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsNothing);

    expect(find.byKey(const Key('tripFlightPicker-flight-2')), findsOneWidget);
  });
  testWidgets('allows selecting multiple flights', (tester) async {
    final flights = [
      sampleFlight(id: 'flight-1'),
      sampleFlight(id: 'flight-2'),
    ];

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripFlightPicker-flight-1')));

    await tester.tap(find.byKey(const Key('tripFlightPicker-flight-2')));

    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);

    expect(find.text('Add 2 flights'), findsOneWidget);
  });
  testWidgets('returns selected flight IDs on confirmation', (tester) async {
    final flights = [
      sampleFlight(id: 'flight-1'),
      sampleFlight(id: 'flight-2'),
      sampleFlight(id: 'flight-3'),
    ];

    List<String>? selectedIds;

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
        onSelection: (ids) {
          selectedIds = ids;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripFlightPicker-flight-1')));

    await tester.tap(find.byKey(const Key('tripFlightPicker-flight-3')));

    await tester.pumpAndSettle();

    expect(find.text('Add 2 flights'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmTripFlightSelection')));

    await tester.pumpAndSettle();

    expect(selectedIds, ['flight-1', 'flight-3']);

    expect(find.text('Add flights'), findsNothing);
  });
  testWidgets('cancel returns null without selecting flights', (tester) async {
    final flights = [sampleFlight(id: 'flight-1')];

    List<String>? selectedIds;
    var callbackCalled = false;

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository(flights),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
        onSelection: (ids) {
          callbackCalled = true;
          selectedIds = ids;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tripFlightPicker-flight-1')));

    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Cancel'));

    await tester.pumpAndSettle();

    expect(callbackCalled, isTrue);
    expect(selectedIds, isNull);

    expect(find.text('Add flights'), findsNothing);
  });
  testWidgets('loads another page of flights', (tester) async {
    final flights = [
      for (var index = 0; index < 55; index++)
        sampleFlight(id: 'flight-$index', flightNumber: 'TP${1000 + index}'),
    ];

    final repository = FakePickerFlightRepository(flights);

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: repository,
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(repository.loadCalls, 1);

    // The first page contains 50 flights.
    expect(find.byKey(const Key('tripFlightPicker-flight-0')), findsOneWidget);

    final loadMore = find.byKey(const Key('tripFlightPickerLoadMore'));

    await tester.scrollUntilVisible(
      loadMore,
      300,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(loadMore);

    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);

    // Search for a flight only present on the second page.
    await tester.enterText(
      find.byKey(const Key('tripFlightPickerSearch')),
      'TP1054',
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripFlightPicker-flight-54')), findsOneWidget);

    expect(find.byKey(const Key('tripFlightPickerLoadMore')), findsNothing);
  });
  testWidgets('shows loading error and supports retry', (tester) async {
    final repository = FakePickerFlightRepository([
      sampleFlight(id: 'flight-1'),
    ]);

    repository.failNextLoad = true;

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: repository,
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(find.text('Unable to retrieve flights.'), findsOneWidget);

    expect(find.byKey(const Key('retryTripFlightPicker')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retryTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);

    expect(find.byKey(const Key('tripFlightPicker-flight-1')), findsOneWidget);

    expect(find.text('Unable to retrieve flights.'), findsNothing);
  });
  testWidgets('uses a dialog on desktop', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository([
          sampleFlight(id: 'flight-1'),
        ]),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Add flights'), findsOneWidget);
  });
  testWidgets('uses a bottom sheet on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        flightRepository: FakePickerFlightRepository([
          sampleFlight(id: 'flight-1'),
        ]),
        airportRepository: FakePickerAirportRepository(),
        airlineRepository: FakePickerAirlineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('openTripFlightPicker')));

    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Add flights'), findsOneWidget);
  });
}
