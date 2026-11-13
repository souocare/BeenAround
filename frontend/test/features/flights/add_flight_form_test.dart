import 'dart:async';
import 'package:beenaround/features/flights/application/save_flight_cubit.dart';
import 'package:beenaround/features/flights/domain/flight_repository.dart';
import 'package:beenaround/features/flights/presentation/widgets/add_flight_form.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/domain/flight_input.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';

import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';

import 'package:beenaround/features/flights/presentation/widgets/show_add_flight.dart';

/// The repository must never be called by tests that only
/// validate presentation and incomplete form submissions.
class FakeFlightRepository extends Fake implements FlightRepository {}

class RecordingFlightRepository extends Fake implements FlightRepository {
  FlightCreateInput? lastInput;
  int createCalls = 0;

  @override
  Future<Flight> createFlight({required FlightCreateInput input}) async {
    createCalls++;
    lastInput = input;

    return Flight(
      id: 'created-flight',
      departureAirportId: input.departureAirportId,
      arrivalAirportId: input.arrivalAirportId,
      departureOn: input.departureOn,
      departureTime: input.departureTime,
      arrivalOn: input.arrivalOn,
      arrivalTime: input.arrivalTime,
      status: input.status,
      airlineId: input.airlineId,
      airlineName: input.airlineName,
      flightNumber: input.flightNumber,
      aircraftType: input.aircraftType,
      aircraftRegistration: input.aircraftRegistration,
      seat: input.seat,
      cabinClass: input.cabinClass,
      notes: input.notes,
      createdAt: DateTime.utc(2026, 11, 13),
      updatedAt: DateTime.utc(2026, 11, 13),
    );
  }
}

class IntegrationCountriesRepository extends Fake
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

class IntegrationAirportRepository extends Fake implements AirportRepository {
  static const lisbon = Airport(
    id: 100,
    ident: 'LPPT',
    iataCode: 'LIS',
    icaoCode: 'LPPT',
    name: 'Humberto Delgado Airport',
    municipality: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    type: 'large_airport',
    scheduledService: true,
  );

  static const barcelona = Airport(
    id: 200,
    ident: 'LEBL',
    iataCode: 'BCN',
    icaoCode: 'LEBL',
    name: 'Josep Tarradellas Barcelona-El Prat Airport',
    municipality: 'Barcelona',
    countryCode: 'ES',
    countryName: 'Spain',
    type: 'large_airport',
    scheduledService: true,
  );

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final airports = [lisbon, barcelona];

    final normalizedQuery = query?.trim().toLowerCase();

    final matches = airports
        .where((airport) {
          if (countryCode != null && airport.countryCode != countryCode) {
            return false;
          }

          if (scheduledOnly && !airport.scheduledService) {
            return false;
          }

          if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
            return airport.displayCode.toLowerCase().contains(
                  normalizedQuery,
                ) ||
                airport.name.toLowerCase().contains(normalizedQuery) ||
                (airport.municipality?.toLowerCase().contains(
                      normalizedQuery,
                    ) ??
                    false);
          }

          return true;
        })
        .toList(growable: false);

    return AirportPage(
      items: matches.skip(offset).take(limit).toList(growable: false),
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airport> getAirport({required int airportId}) async {
    return switch (airportId) {
      100 => lisbon,
      200 => barcelona,
      _ => throw StateError('Unknown test airport: $airportId'),
    };
  }
}

class IntegrationAirlineRepository extends Fake implements AirlineRepository {
  static const tap = Airline(
    id: 10,
    name: 'TAP Air Portugal',
    iataCode: 'TP',
    icaoCode: 'TAP',
    countryName: 'Portugal',
  );

  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalized = query?.trim().toLowerCase() ?? '';

    final matches = [tap]
        .where((airline) {
          if (normalized.isEmpty) return true;

          return airline.name.toLowerCase().contains(normalized) ||
              (airline.iataCode?.toLowerCase().contains(normalized) ?? false) ||
              (airline.icaoCode?.toLowerCase().contains(normalized) ?? false);
        })
        .toList(growable: false);

    return AirlinePage(
      items: matches.skip(offset).take(limit).toList(growable: false),
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airline> getAirline({required int airlineId}) async {
    if (airlineId == 10) {
      return tap;
    }

    throw StateError('Unknown test airline: $airlineId');
  }
}

class FlakyFlightRepository extends RecordingFlightRepository {
  bool _shouldFail = true;

  @override
  Future<Flight> createFlight({required FlightCreateInput input}) async {
    if (_shouldFail) {
      _shouldFail = false;

      createCalls++;
      lastInput = input;

      throw StateError('Simulated server failure');
    }

    return super.createFlight(input: input);
  }
}

class DelayedDetectionAirlineRepository extends IntegrationAirlineRepository {
  final detectionCompleter = Completer<AirlinePage>();

  @override
  Future<AirlinePage> search({String? query, int limit = 20, int offset = 0}) {
    // Delay only the exact-code lookup used by
    // automatic flight-number detection.
    if (query?.toUpperCase() == 'TP') {
      return detectionCompleter.future;
    }

    return super.search(query: query, limit: limit, offset: offset);
  }

  void completeDetection() {
    if (detectionCompleter.isCompleted) return;

    detectionCompleter.complete(
      const AirlinePage(
        items: [IntegrationAirlineRepository.tap],
        total: 1,
        limit: 100,
        offset: 0,
      ),
    );
  }
}

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        home: Scaffold(
          body: BlocProvider<SaveFlightCubit>(
            create: (_) => SaveFlightCubit(repository: FakeFlightRepository()),
            child: const AddFlightForm(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpIntegrationApp(
    WidgetTester tester, {
    required RecordingFlightRepository flightRepository,
    required ValueChanged<bool> onResult,
    ValueChanged<Flight?>? onCreatedFlight,
    TargetPlatform platform = TargetPlatform.iOS,
    AirlineRepository? airlineRepository,
  }) async {
    // Simulate a phone-sized screen.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FlightRepository>.value(value: flightRepository),
          RepositoryProvider<AirportRepository>.value(
            value: IntegrationAirportRepository(),
          ),
          RepositoryProvider<AirlineRepository>.value(
            value: airlineRepository ?? IntegrationAirlineRepository(),
          ),
          RepositoryProvider<CountriesRepository>.value(
            value: IntegrationCountriesRepository(),
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
                      if (onCreatedFlight != null) {
                        final flight = await showAddFlightWithResult(context);
                        onCreatedFlight(flight);
                        return;
                      }

                      final result = await showAddFlight(context);
                      onResult(result);
                    },
                    child: const Text('Open Add Flight'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Add Flight'));
    await tester.pumpAndSettle();

    expect(find.text('Add Flight'), findsOneWidget);
  }

  Future<void> selectAirport(
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

    // Select country.
    await tester.tap(find.byKey(ValueKey('airport-country-$countryCode')));

    await tester.pumpAndSettle();

    // Select airport.
    await tester.tap(find.byKey(ValueKey('airport-$airportId')));

    await tester.pumpAndSettle();
  }

  group('Add Flight - Flight Schedule', () {
    testWidgets('shows all four schedule fields immediately', (tester) async {
      await pumpForm(tester);

      expect(find.byKey(const Key('departureDateField')), findsOneWidget);

      expect(find.byKey(const Key('departureTimeField')), findsOneWidget);

      expect(find.byKey(const Key('arrivalDateField')), findsOneWidget);

      expect(find.byKey(const Key('arrivalTimeField')), findsOneWidget);

      expect(find.text('FLIGHT SCHEDULE'), findsOneWidget);

      // Additional Details should be collapsed by default.
      expect(find.byKey(const Key('aircraftTypeField')), findsNothing);
    });

    testWidgets('schedule remains available when details are expanded', (
      tester,
    ) async {
      await pumpForm(tester);

      final toggle = find.byKey(const Key('toggleFlightDetails'));

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aircraftTypeField')), findsOneWidget);

      expect(find.byKey(const Key('departureDateField')), findsOneWidget);

      expect(find.byKey(const Key('departureTimeField')), findsOneWidget);

      expect(find.byKey(const Key('arrivalDateField')), findsOneWidget);

      expect(find.byKey(const Key('arrivalTimeField')), findsOneWidget);
    });

    testWidgets('optional schedule fields start empty', (tester) async {
      await pumpForm(tester);

      expect(find.text('Add date'), findsOneWidget);
      expect(find.text('Add time'), findsNWidgets(2));

      // Departure date is required and already initialized.
      expect(find.byKey(const Key('departureDateField')), findsOneWidget);
    });
  });

  group('Add Flight - Additional Details', () {
    testWidgets('details can be expanded and collapsed', (tester) async {
      await pumpForm(tester);

      final toggle = find.byKey(const Key('toggleFlightDetails'));

      expect(find.byKey(const Key('cabinClassField')), findsNothing);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cabinClassField')), findsOneWidget);

      expect(find.byKey(const Key('aircraftTypeField')), findsOneWidget);

      expect(
        find.byKey(const Key('aircraftRegistrationField')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('seatField')), findsOneWidget);

      expect(find.byKey(const Key('flightNotesField')), findsOneWidget);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aircraftTypeField')), findsNothing);
    });
  });

  group('Add Flight - Validation', () {
    testWidgets('cannot save without departure and arrival airports', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.byKey(const Key('saveFlightButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Select both departure and arrival airports.'),
        findsOneWidget,
      );

      // The form remains open.
      expect(find.text('Add Flight'), findsOneWidget);
    });
    group('Add Flight - Time Selection', () {
      testWidgets('cancelling an iOS time picker preserves the empty value', (
        tester,
      ) async {
        await pumpForm(tester, platform: TargetPlatform.iOS);

        final departureTime = find.byKey(const Key('departureTimeField'));

        await tester.ensureVisible(departureTime);
        await tester.tap(departureTime);
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Add time'), findsNWidgets(2));
      });

      testWidgets('confirming an iOS time picker updates the field', (
        tester,
      ) async {
        await pumpForm(tester, platform: TargetPlatform.iOS);

        final departureTime = find.byKey(const Key('departureTimeField'));

        await tester.ensureVisible(departureTime);
        await tester.tap(departureTime);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // The form starts the picker at 12:00 when no
        // previous departure time has been selected.
        expect(find.text('12:00'), findsOneWidget);

        expect(find.byTooltip('Clear Time'), findsOneWidget);
      });

      testWidgets('clearing departure time restores the placeholder', (
        tester,
      ) async {
        await pumpForm(tester, platform: TargetPlatform.iOS);

        final departureTime = find.byKey(const Key('departureTimeField'));

        await tester.ensureVisible(departureTime);
        await tester.tap(departureTime);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Clear Time'));
        await tester.pumpAndSettle();

        expect(find.text('Add time'), findsNWidgets(2));
      });
    });
  });
  group('Add Flight - Integration', () {
    testWidgets('creates a flight with normalized number and local time', (
      tester,
    ) async {
      final repository = RecordingFlightRepository();

      bool? result;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (value) {
          result = value;
        },
      );

      // --------------------------------------------------
      // Flight number
      // --------------------------------------------------
      await tester.enterText(
        find.byKey(const Key('flightNumberField')),
        'TP 1019',
      );

      // Allow automatic airline detection to complete.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // --------------------------------------------------
      // Route: Lisbon -> Barcelona
      // --------------------------------------------------
      await selectAirport(
        tester,
        fieldKey: 'departureAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      await selectAirport(
        tester,
        fieldKey: 'arrivalAirportField',
        countryCode: 'ES',
        airportId: 200,
      );

      // --------------------------------------------------
      // Departure time
      // --------------------------------------------------
      final departureTime = find.byKey(const Key('departureTimeField'));

      await tester.ensureVisible(departureTime);
      await tester.pumpAndSettle();

      await tester.tap(departureTime);
      await tester.pumpAndSettle();

      // Cupertino picker initially opens at 12:00.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // --------------------------------------------------
      // Save
      // --------------------------------------------------
      await tester.tap(find.byKey(const Key('saveFlightButton')));

      await tester.pumpAndSettle();

      // --------------------------------------------------
      // Assertions
      // --------------------------------------------------
      expect(repository.createCalls, 1);

      final input = repository.lastInput;

      expect(input, isNotNull);

      expect(input!.departureAirportId, 100);
      expect(input.arrivalAirportId, 200);

      expect(input.flightNumber, 'TP1019');

      expect(input.airlineId, 10);
      expect(input.airlineName, isNull);

      expect(input.departureTime, '12:00');

      // Arrival date and time are optional.
      expect(input.arrivalOn, isNull);
      expect(input.arrivalTime, isNull);

      expect(input.status, FlightStatus.flown);

      // The form closes after successful persistence.
      expect(result, isTrue);
      expect(find.text('Add Flight'), findsNothing);
    });
    testWidgets('closing Add Flight returns false without creating a flight', (
      tester,
    ) async {
      final repository = RecordingFlightRepository();

      bool? result;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (value) {
          result = value;
        },
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(repository.createCalls, 0);
    });
    testWidgets('rejects a flight with identical airports', (tester) async {
      final repository = RecordingFlightRepository();

      bool? result;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (value) {
          result = value;
        },
      );

      await selectAirport(
        tester,
        fieldKey: 'departureAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      await selectAirport(
        tester,
        fieldKey: 'arrivalAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      await tester.tap(find.byKey(const Key('saveFlightButton')));

      await tester.pumpAndSettle();

      expect(
        find.text('Departure and arrival airports must be different.'),
        findsOneWidget,
      );

      expect(repository.createCalls, 0);
      expect(result, isNull);
    });
    testWidgets('saves departure and arrival local dates and times', (
      tester,
    ) async {
      final repository = RecordingFlightRepository();

      bool? result;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        platform: TargetPlatform.android,
        onResult: (value) => result = value,
      );

      await selectAirport(
        tester,
        fieldKey: 'departureAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      await selectAirport(
        tester,
        fieldKey: 'arrivalAirportField',
        countryCode: 'ES',
        airportId: 200,
      );

      // Departure time.
      final departureTimeField = find.byKey(const Key('departureTimeField'));

      await tester.ensureVisible(departureTimeField);
      await tester.pumpAndSettle();

      await tester.tap(departureTimeField);
      await tester.pumpAndSettle();

      // Confirm the initial 12:00 time.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Arrival date.
      final arrivalDateField = find.byKey(const Key('arrivalDateField'));

      await tester.ensureVisible(arrivalDateField);
      await tester.pumpAndSettle();

      await tester.tap(arrivalDateField);
      await tester.pumpAndSettle();

      // Confirm the initially suggested departure date.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Arrival time.
      final arrivalTimeField = find.byKey(const Key('arrivalTimeField'));

      await tester.ensureVisible(arrivalTimeField);
      await tester.pumpAndSettle();

      await tester.tap(arrivalTimeField);
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save.
      final saveButton = find.byKey(const Key('saveFlightButton'));

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      final input = repository.lastInput;

      expect(input, isNotNull);

      expect(input!.departureAirportId, 100);
      expect(input.arrivalAirportId, 200);

      // Both values are local wall-clock times.
      expect(input.departureTime, '12:00');
      expect(input.arrivalTime, '12:00');

      // Arrival date was explicitly selected.
      expect(input.arrivalOn, isNotNull);
      expect(input.arrivalOn, input.departureOn);

      expect(result, isTrue);
    });
    testWidgets('keeps the form open after a save failure and allows retry', (
      tester,
    ) async {
      final repository = FlakyFlightRepository();

      bool? result;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (value) => result = value,
      );

      await selectAirport(
        tester,
        fieldKey: 'departureAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      await selectAirport(
        tester,
        fieldKey: 'arrivalAirportField',
        countryCode: 'ES',
        airportId: 200,
      );

      await tester.enterText(
        find.byKey(const Key('flightNumberField')),
        'TP 1019',
      );

      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('saveFlightButton'));

      // First attempt fails.
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      expect(find.text('Unable to save your flight.'), findsOneWidget);

      expect(find.text('Add Flight'), findsOneWidget);
      expect(result, isNull);

      // Second attempt succeeds.
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 2);

      expect(repository.lastInput, isNotNull);
      expect(repository.lastInput!.flightNumber, 'TP1019');

      expect(result, isTrue);
      expect(find.text('Add Flight'), findsNothing);
    });
    testWidgets(
      'manual airline selection survives a delayed detection result',
      (tester) async {
        final flightRepository = RecordingFlightRepository();
        final airlineRepository = DelayedDetectionAirlineRepository();

        bool? result;

        await pumpIntegrationApp(
          tester,
          flightRepository: flightRepository,
          airlineRepository: airlineRepository,
          onResult: (value) => result = value,
        );

        // Enter a flight number that triggers automatic detection.
        await tester.enterText(
          find.byKey(const Key('flightNumberField')),
          'TP1019',
        );

        // Advance beyond the 350 ms debounce.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(airlineRepository.detectionCompleter.isCompleted, isFalse);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Open the airline picker before detection returns.
        final airlineField = find.byKey(const Key('airlineField'));

        await tester.ensureVisible(airlineField);
        await tester.pump();

        await tester.tap(airlineField);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Choose manual entry.
        await tester.tap(find.byKey(const Key('enterManualAirline')));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(
          find.byKey(const Key('manualAirlineNameField')),
          'Air Berlin',
        );

        await tester.tap(find.byKey(const Key('confirmManualAirline')));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Air Berlin'), findsOneWidget);

        // The earlier automatic request now completes.
        airlineRepository.completeDetection();

        await tester.pumpAndSettle();

        // The manually chosen company must remain selected.
        expect(find.text('Air Berlin'), findsOneWidget);

        expect(find.text('TAP Air Portugal'), findsNothing);

        // Complete the route and save to verify the actual payload.
        await selectAirport(
          tester,
          fieldKey: 'departureAirportField',
          countryCode: 'PT',
          airportId: 100,
        );

        await selectAirport(
          tester,
          fieldKey: 'arrivalAirportField',
          countryCode: 'ES',
          airportId: 200,
        );

        await tester.tap(find.byKey(const Key('saveFlightButton')));

        await tester.pumpAndSettle();

        expect(flightRepository.createCalls, 1);

        final input = flightRepository.lastInput;

        expect(input, isNotNull);

        expect(input!.airlineId, isNull);
        expect(input.airlineName, 'Air Berlin');

        expect(input.flightNumber, 'TP1019');

        expect(result, isTrue);
      },
    );
    testWidgets('showAddFlightWithResult returns the created Flight', (
      tester,
    ) async {
      final repository = RecordingFlightRepository();

      Flight? createdFlight;
      var callbackCalled = false;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (_) {},
        onCreatedFlight: (flight) {
          callbackCalled = true;
          createdFlight = flight;
        },
      );

      // Select departure airport.
      await selectAirport(
        tester,
        fieldKey: 'departureAirportField',
        countryCode: 'PT',
        airportId: 100,
      );

      // Select arrival airport.
      await selectAirport(
        tester,
        fieldKey: 'arrivalAirportField',
        countryCode: 'ES',
        airportId: 200,
      );

      // Enter flight number.
      await tester.enterText(
        find.byKey(const Key('flightNumberField')),
        'TP 1019',
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Persist the Flight.
      await tester.tap(find.byKey(const Key('saveFlightButton')));

      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      expect(callbackCalled, isTrue);
      expect(createdFlight, isNotNull);

      expect(createdFlight!.id, 'created-flight');
      expect(createdFlight!.departureAirportId, 100);
      expect(createdFlight!.arrivalAirportId, 200);

      expect(createdFlight!.flightNumber, 'TP1019');

      expect(find.text('Add Flight'), findsNothing);
    });
    testWidgets('showAddFlightWithResult returns null on cancellation', (
      tester,
    ) async {
      final repository = RecordingFlightRepository();

      Flight? createdFlight;
      var callbackCalled = false;

      await pumpIntegrationApp(
        tester,
        flightRepository: repository,
        onResult: (_) {},
        onCreatedFlight: (flight) {
          callbackCalled = true;
          createdFlight = flight;
        },
      );

      expect(find.text('Add Flight'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));

      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
      expect(createdFlight, isNull);

      expect(repository.createCalls, 0);

      expect(find.text('Add Flight'), findsNothing);
    });
    testWidgets(
      'showAddFlightWithResult keeps form open after creation failure',
      (tester) async {
        final repository = FlakyFlightRepository();

        Flight? createdFlight;
        var callbackCalled = false;

        await pumpIntegrationApp(
          tester,
          flightRepository: repository,
          onResult: (_) {},
          onCreatedFlight: (flight) {
            callbackCalled = true;
            createdFlight = flight;
          },
        );

        await selectAirport(
          tester,
          fieldKey: 'departureAirportField',
          countryCode: 'PT',
          airportId: 100,
        );

        await selectAirport(
          tester,
          fieldKey: 'arrivalAirportField',
          countryCode: 'ES',
          airportId: 200,
        );

        await tester.tap(find.byKey(const Key('saveFlightButton')));

        await tester.pumpAndSettle();

        // First request failed.
        expect(repository.createCalls, 1);

        expect(find.text('Unable to save your flight.'), findsOneWidget);

        // The form remains available for retry.
        expect(find.text('Add Flight'), findsOneWidget);

        expect(callbackCalled, isFalse);
        expect(createdFlight, isNull);

        // Retry.
        await tester.tap(find.byKey(const Key('saveFlightButton')));

        await tester.pumpAndSettle();

        expect(repository.createCalls, 2);

        expect(callbackCalled, isTrue);
        expect(createdFlight?.id, 'created-flight');

        expect(find.text('Add Flight'), findsNothing);
      },
    );
  });
}
