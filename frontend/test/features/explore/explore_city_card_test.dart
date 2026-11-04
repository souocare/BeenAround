import 'package:beenaround/features/explore/application/explore_city_aggregation.dart';
import 'package:beenaround/features/explore/application/explore_city_summary.dart';
import 'package:beenaround/features/explore/presentation/widgets/explore_city_card.dart';
import 'package:beenaround/features/geography/domain/city.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const city = City(
    id: 2267057,
    name: 'Lisbon',
    asciiName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    latitude: 38.72,
    longitude: -9.13,
    population: 500000,
    featureCode: 'PPLC',
  );

  Future<void> pumpCityCard(
    WidgetTester tester, {
    required int visitCount,
    required int residenceCount,
    required bool isWishlisted,
    VoidCallback? onTap,
  }) async {
    final entry = ExploreCityEntry(
      city: city,
      summary: ExploreCitySummary(
        cityId: city.id,
        visitCount: visitCount,
        residenceCount: residenceCount,
        isWishlisted: isWishlisted,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreCityCard(entry: entry, onTap: onTap ?? () {}),
        ),
      ),
    );
  }

  testWidgets('shows explicit visits', (tester) async {
    await pumpCityCard(
      tester,
      visitCount: 2,
      residenceCount: 0,
      isWishlisted: false,
    );

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Portugal · 2 visits'), findsOneWidget);

    expect(find.byKey(const Key('visitedCityCard-2267057')), findsOneWidget);
  });

  testWidgets('shows residence without visits', (tester) async {
    await pumpCityCard(
      tester,
      visitCount: 0,
      residenceCount: 1,
      isWishlisted: false,
    );

    expect(find.text('Portugal · Lived'), findsOneWidget);
    expect(find.textContaining('0 visits'), findsNothing);
  });

  testWidgets('shows wishlist without visits', (tester) async {
    await pumpCityCard(
      tester,
      visitCount: 0,
      residenceCount: 0,
      isWishlisted: true,
    );

    expect(find.text('Portugal · Wishlist'), findsOneWidget);
    expect(find.textContaining('0 visits'), findsNothing);
  });

  testWidgets('shows combined statuses without duplicates', (tester) async {
    await pumpCityCard(
      tester,
      visitCount: 2,
      residenceCount: 1,
      isWishlisted: true,
    );

    expect(find.text('Portugal · 2 visits · Lived · Wishlist'), findsOneWidget);

    expect(find.text('Lisbon'), findsOneWidget);
  });

  testWidgets('calls onTap when the city is selected', (tester) async {
    var tapped = false;

    await pumpCityCard(
      tester,
      visitCount: 0,
      residenceCount: 0,
      isWishlisted: true,
      onTap: () => tapped = true,
    );

    await tester.tap(find.byKey(const Key('visitedCityCard-2267057')));

    expect(tapped, isTrue);
  });
}
