import 'package:beenaround/app/widgets/country_flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays the Portuguese flag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CountryFlag(countryCode: 'PT')),
      ),
    );

    expect(find.text('🇵🇹'), findsOneWidget);
  });

  testWidgets('displays a fallback for an invalid code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CountryFlag(countryCode: '')),
      ),
    );

    expect(find.text('🌍'), findsOneWidget);
  });
}
