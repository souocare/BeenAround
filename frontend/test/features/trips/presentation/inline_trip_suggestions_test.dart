import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/trips/application/trip_suggestions.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_date_compatibility.dart';
import 'package:beenaround/features/trips/presentation/widgets/inline_trip_suggestions.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PartialVisitDate day(int year, int month, int day) {
  return PartialVisitDate(
    date: DateTime(year, month, day),
    precision: VisitDatePrecision.day,
  );
}

Trip trip(
  String id,
  String name, {
  PartialVisitDate? start,
  PartialVisitDate? end,
}) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: start,
    endedOn: end,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

TripSuggestion suggestion(
  String id,
  String name, {
  TripDateCompatibility compatibility = TripDateCompatibility.match,
}) {
  return TripSuggestion(trip: trip(id, name), compatibility: compatibility);
}

Widget buildTestApp({
  required List<TripSuggestion> suggestions,
  required ValueChanged<String> onTripSelected,
  bool enabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: InlineTripSuggestions(
          suggestions: suggestions,
          onTripSelected: onTripSelected,
          enabled: enabled,
        ),
      ),
    ),
  );
}

void main() {
  group('Inline Trip Suggestions', () {
    testWidgets('does not render when suggestions are empty', (tester) async {
      await tester.pumpWidget(
        buildTestApp(suggestions: const [], onTripSelected: (_) {}),
      );

      expect(find.byKey(const Key('inlineTripSuggestions')), findsNothing);
    });

    testWidgets('shows compatible Trips', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          suggestions: [
            suggestion('trip-1', 'Japan 2027'),
            suggestion(
              'trip-2',
              'Asia 2027',
              compatibility: TripDateCompatibility.possible,
            ),
          ],
          onTripSelected: (_) {},
        ),
      );

      expect(find.byKey(const Key('inlineTripSuggestions')), findsOneWidget);

      expect(find.text('Japan 2027'), findsOneWidget);
      expect(find.text('Asia 2027'), findsOneWidget);

      expect(find.text('Dates overlap with your visit'), findsOneWidget);

      expect(find.text('Possible date match'), findsOneWidget);
    });

    testWidgets('selecting a suggestion reports the correct Trip ID', (
      tester,
    ) async {
      String? selectedTripId;

      await tester.pumpWidget(
        buildTestApp(
          suggestions: [suggestion('trip-1', 'Japan 2027')],
          onTripSelected: (tripId) {
            selectedTripId = tripId;
          },
        ),
      );

      expect(selectedTripId, isNull);

      await tester.tap(find.byKey(const Key('selectSuggestedTrip-trip-1')));

      await tester.pump();

      expect(selectedTripId, 'trip-1');
    });

    testWidgets('does not select a Trip without user interaction', (
      tester,
    ) async {
      var selections = 0;

      await tester.pumpWidget(
        buildTestApp(
          suggestions: [suggestion('trip-1', 'Japan 2027')],
          onTripSelected: (_) {
            selections++;
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(selections, 0);
    });

    testWidgets('disabled suggestions cannot be selected', (tester) async {
      var selections = 0;

      await tester.pumpWidget(
        buildTestApp(
          suggestions: [suggestion('trip-1', 'Japan 2027')],
          enabled: false,
          onTripSelected: (_) {
            selections++;
          },
        ),
      );

      final button = tester.widget<TextButton>(
        find.byKey(const Key('selectSuggestedTrip-trip-1')),
      );

      expect(button.onPressed, isNull);
      expect(selections, 0);
    });

    testWidgets('allows selection from multiple suggested Trips', (
      tester,
    ) async {
      final selections = <String>[];

      await tester.pumpWidget(
        buildTestApp(
          suggestions: [
            suggestion('trip-1', 'Japan 2027'),
            suggestion('trip-2', 'Asia 2027'),
          ],
          onTripSelected: selections.add,
        ),
      );

      await tester.tap(find.byKey(const Key('selectSuggestedTrip-trip-1')));

      await tester.tap(find.byKey(const Key('selectSuggestedTrip-trip-2')));

      expect(selections, ['trip-1', 'trip-2']);
    });

    testWidgets('updates displayed suggestions when input changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          suggestions: [suggestion('trip-1', 'Japan 2027')],
          onTripSelected: (_) {},
        ),
      );

      expect(find.text('Japan 2027'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(
          suggestions: [suggestion('trip-2', 'Portugal 2027')],
          onTripSelected: (_) {},
        ),
      );

      expect(find.text('Japan 2027'), findsNothing);
      expect(find.text('Portugal 2027'), findsOneWidget);
    });

    testWidgets('displays suggestions correctly on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        await tester.pumpWidget(
          buildTestApp(
            suggestions: [suggestion('trip-1', 'Japan 2027')],
            onTripSelected: (_) {},
          ),
        );

        expect(find.byKey(const Key('inlineTripSuggestions')), findsOneWidget);

        expect(find.text('Japan 2027'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
