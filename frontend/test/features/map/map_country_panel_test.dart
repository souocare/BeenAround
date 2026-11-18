import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/domain/map_country_preview.dart';
import 'package:beenaround/features/map/presentation/widgets/map_country_panel.dart';
import 'package:beenaround/features/map/application/map_country_related_state.dart';

void main() {
  const preview = MapCountryPreview(
    countryCode: 'ES',
    countryName: 'Spain',
    visitCount: 3,
    residenceCount: 1,
    isCountryWishlisted: true,
    hasWishlistedCities: true,
  );

  testWidgets('shows selected country information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCountryPanel(
            preview: preview,
            onClose: _noop,
            onViewDetails: () {},
            relatedState: const MapCountryRelatedState(),
          ),
        ),
      ),
    );

    expect(find.text('Spain'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Lived'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);

    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Cities'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
  });

  testWidgets('allows closing the panel', (tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCountryPanel(
            preview: preview,
            onClose: () => closed = true,
            relatedState: const MapCountryRelatedState(),
            onViewDetails: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mapCountryPanelClose')));

    expect(closed, isTrue);
  });
  testWidgets('opens country details when action is pressed', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCountryPanel(
            preview: preview,
            relatedState: const MapCountryRelatedState(),
            onClose: () {},
            onViewDetails: () => opened = true,
          ),
        ),
      ),
    );

    final button = find.byKey(const Key('mapCountryViewDetails'));

    // The button is lower in the scrollable content.
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);

    expect(opened, isTrue);
  });
}

void _noop() {}
