import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/flights/domain/airline.dart';

import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';

import 'package:beenaround/features/flights/presentation/widgets/show_edit_flight.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlightRepository extends Fake implements FlightRepository {
  int updateCalls = 0;

  FlightPatch? lastPatch;

  @override
  Future<Flight> updateFlight({
    required String flightId,
    required FlightPatch patch,
  }) async {
    updateCalls++;
    lastPatch = patch;

    return _flight;
  }
}

class _AirportRepository extends Fake implements AirportRepository {}

class _AirlineRepository extends Fake implements AirlineRepository {
  int searchCalls = 0;

  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCalls++;

    return AirlinePage(items: const [], total: 0, limit: limit, offset: offset);
  }
}

class _CountriesRepository extends Fake implements CountriesRepository {}

final _timestamp = DateTime.utc(2026, 10, 10);

final _flight = Flight(
  id: 'flight-1',
  departureAirportId: 100,
  arrivalAirportId: 200,
  departureOn: '2026-10-10',
  departureTime: '19:20:00',
  arrivalOn: '2026-10-10',
  arrivalTime: '22:15:00',
  status: FlightStatus.flown,
  flightNumber: 'TP1019',
  airlineName: 'TAP Air Portugal',
  seat: '12A',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

const _lisbon = Airport(
  id: 100,
  ident: 'LPPT',
  iataCode: 'LIS',
  icaoCode: 'LPPT',
  name: 'Lisbon Airport',
  municipality: 'Lisbon',
  countryCode: 'PT',
  countryName: 'Portugal',
  type: 'large_airport',
  scheduledService: true,
);

const _barcelona = Airport(
  id: 200,
  ident: 'LEBL',
  iataCode: 'BCN',
  icaoCode: 'LEBL',
  name: 'Barcelona Airport',
  municipality: 'Barcelona',
  countryCode: 'ES',
  countryName: 'Spain',
  type: 'large_airport',
  scheduledService: true,
);

void main() {
  Future<void> pumpEditApp(
    WidgetTester tester, {
    required _FlightRepository repository,
    required ValueChanged<bool> onResult,
    TargetPlatform platform = TargetPlatform.android,
    _AirlineRepository? airlineRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FlightRepository>.value(value: repository),
          RepositoryProvider<AirportRepository>.value(
            value: _AirportRepository(),
          ),
          RepositoryProvider<AirlineRepository>.value(
            value: airlineRepository ?? _AirlineRepository(),
          ),
          RepositoryProvider<CountriesRepository>.value(
            value: _CountriesRepository(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform, useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: FilledButton(
                    onPressed: () async {
                      final result = await showEditFlight(
                        context,
                        flight: _flight,
                        departureAirport: _lisbon,
                        arrivalAirport: _barcelona,
                        airline: null,
                      );

                      onResult(result);
                    },
                    child: const Text('Open Edit Flight'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openEdit(WidgetTester tester) async {
    await tester.tap(find.text('Open Edit Flight'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Flight'), findsOneWidget);
  }

  Future<void> changeSeat(WidgetTester tester, String value) async {
    final seatField = find.byKey(const Key('seatField'));

    await tester.ensureVisible(seatField);
    await tester.pumpAndSettle();

    await tester.enterText(seatField, value);
    await tester.pumpAndSettle();
  }

  group('Edit Flight form', () {
    late _FlightRepository repository;
    late bool? result;

    setUp(() {
      repository = _FlightRepository();
      result = null;
    });

    testWidgets('loads existing values', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      expect(find.text('TP1019'), findsOneWidget);

      expect(find.text('TAP Air Portugal'), findsWidgets);

      expect(find.text('LIS'), findsWidgets);

      expect(find.text('BCN'), findsWidgets);

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('seatField')))
            .controller!
            .text,
        '12A',
      );
    });

    testWidgets('closing unchanged form does not update', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await tester.tap(find.byTooltip('Close'));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 0);
      expect(result, isFalse);

      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('changing seat and closing requires confirmation', (
      tester,
    ) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await changeSeat(tester, '14A');

      await tester.tap(find.byTooltip('Close'));

      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);

      expect(repository.updateCalls, 0);
    });

    testWidgets('Keep Editing preserves the form', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await changeSeat(tester, '14A');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Flight'), findsOneWidget);

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('seatField')))
            .controller!
            .text,
        '14A',
      );

      expect(repository.updateCalls, 0);
    });

    testWidgets('Discard Changes closes without PATCH', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await changeSeat(tester, '14A');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(repository.updateCalls, 0);
      expect(find.text('Edit Flight'), findsNothing);
    });

    testWidgets('Save Changes sends minimal PATCH', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await changeSeat(tester, '14A');

      final saveButton = find.byKey(const Key('saveFlightButton'));

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.lastPatch?.toJson(), {'seat': '14A'});

      expect(result, isTrue);
      expect(find.text('Edit Flight'), findsNothing);
    });

    testWidgets('clearing seat sends explicit null', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await changeSeat(tester, '');

      await tester.tap(find.byKey(const Key('saveFlightButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.lastPatch?.toJson(), {'seat': null});
    });

    testWidgets('Save Changes without edits skips PATCH', (tester) async {
      await pumpEditApp(
        tester,
        repository: repository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      await tester.tap(find.byKey(const Key('saveFlightButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 0);
      expect(result, isFalse);
    });
    testWidgets('does not detect airline during initialization', (
      tester,
    ) async {
      final airlineRepository = _AirlineRepository();

      await pumpEditApp(
        tester,
        repository: repository,
        airlineRepository: airlineRepository,
        onResult: (value) => result = value,
      );

      await openEdit(tester);

      expect(airlineRepository.searchCalls, 0);

      expect(find.text('TAP Air Portugal'), findsWidgets);
    });
  });
}
