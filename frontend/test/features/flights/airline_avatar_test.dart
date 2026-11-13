import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/presentation/widgets/airline_avatar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays airline IATA code', (tester) async {
    const airline = Airline(
      id: 1,
      name: 'TAP Air Portugal',
      iataCode: 'TP',
      icaoCode: 'TAP',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AirlineAvatar(airline: airline)),
      ),
    );

    expect(find.text('TP'), findsOneWidget);
  });

  testWidgets('falls back to ICAO when IATA is unavailable', (tester) async {
    const airline = Airline(id: 2, name: 'Test Airline', icaoCode: 'TST');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AirlineAvatar(airline: airline)),
      ),
    );

    expect(find.text('TST'), findsOneWidget);
  });

  testWidgets('displays fallback icon without airline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AirlineAvatar(airline: null))),
    );

    expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
  });
}
