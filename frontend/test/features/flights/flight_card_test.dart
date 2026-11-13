import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/flight.dart';
import 'package:beenaround/features/flights/presentation/widgets/flight_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 12);

  Flight createFlight({
    FlightStatus status = FlightStatus.flown,
    int? airlineId = 1,
    String? airlineName,
    String? flightNumber = 'TP1234',
  }) {
    return Flight(
      id: 'flight-1',
      departureAirportId: 100,
      arrivalAirportId: 200,
      departureOn: '2026-11-12',
      status: status,
      airlineId: airlineId,
      airlineName: airlineName,
      flightNumber: flightNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  const departure = Airport(
    id: 100,
    ident: 'LPPT',
    iataCode: 'LIS',
    icaoCode: 'LPPT',
    name: 'Lisbon Humberto Delgado Airport',
    municipality: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    type: 'large_airport',
    scheduledService: true,
  );

  const arrival = Airport(
    id: 200,
    ident: 'OMDB',
    iataCode: 'DXB',
    icaoCode: 'OMDB',
    name: 'Dubai International Airport',
    municipality: 'Dubai',
    countryCode: 'AE',
    countryName: 'United Arab Emirates',
    type: 'large_airport',
    scheduledService: true,
  );

  const airline = Airline(
    id: 1,
    name: 'TAP Air Portugal',
    iataCode: 'TP',
    icaoCode: 'TAP',
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required Flight flight,
    Airport? departureAirport = departure,
    Airport? arrivalAirport = arrival,
    Airline? selectedAirline = airline,
    String? airlineName,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCard(
              flight: flight,
              departureAirport: departureAirport,
              arrivalAirport: arrivalAirport,
              airline: selectedAirline,
              airlineName: airlineName,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows route, cities, airline and flight number', (tester) async {
    await pumpCard(tester, flight: createFlight());

    expect(find.text('LIS'), findsOneWidget);
    expect(find.text('DXB'), findsOneWidget);

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Dubai'), findsOneWidget);

    expect(find.text('TAP Air Portugal'), findsOneWidget);
    expect(find.textContaining('TP1234'), findsOneWidget);

    expect(find.text('🇵🇹'), findsOneWidget);
    expect(find.text('🇦🇪'), findsOneWidget);

    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('shows planned status', (tester) async {
    await pumpCard(tester, flight: createFlight(status: FlightStatus.planned));

    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets('shows manually entered airline', (tester) async {
    await pumpCard(
      tester,
      flight: createFlight(airlineId: null, airlineName: 'Air Berlin'),
      selectedAirline: null,
    );

    expect(find.text('Air Berlin'), findsOneWidget);
  });

  testWidgets('works without resolved catalog metadata', (tester) async {
    await pumpCard(
      tester,
      flight: createFlight(
        airlineId: null,
        airlineName: null,
        flightNumber: null,
      ),
      departureAirport: null,
      arrivalAirport: null,
      selectedAirline: null,
    );

    expect(find.text('100'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);

    expect(find.text('Unknown airport'), findsNWidgets(2));
    expect(find.text('Airline not recorded'), findsOneWidget);

    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCard(tester, flight: createFlight());

    expect(tester.takeException(), isNull);
  });
  testWidgets('shows departure date in compact header', (tester) async {
    await pumpCard(tester, flight: createFlight());

    final context = tester.element(find.byType(FlightCard));

    final expectedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(2026, 11, 12));

    expect(find.text(expectedDate), findsOneWidget);

    expect(find.text('TAP Air Portugal'), findsOneWidget);
  });
  testWidgets('does not display an estimated flight duration', (tester) async {
    await pumpCard(tester, flight: createFlight());

    expect(find.textContaining('1h 25m'), findsNothing);
    expect(find.text('Direct'), findsNothing);

    expect(find.text('TP1234'), findsOneWidget);
  });
  testWidgets('retains route information without airline metadata', (
    tester,
  ) async {
    await pumpCard(
      tester,
      flight: createFlight(
        airlineId: null,
        airlineName: null,
        flightNumber: null,
      ),
      selectedAirline: null,
    );

    expect(find.text('LIS'), findsOneWidget);
    expect(find.text('DXB'), findsOneWidget);

    expect(find.text('Airline not recorded'), findsOneWidget);

    expect(find.text('Flight'), findsOneWidget);
  });
}
