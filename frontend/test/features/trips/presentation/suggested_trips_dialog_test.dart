import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';

import 'package:beenaround/features/trips/application/trip_suggestions.dart';
import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_date_compatibility.dart';
import 'package:beenaround/features/trips/presentation/widgets/suggested_trips_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_trip_association_repository.dart';

PartialVisitDate day(int year, int month, int day) {
  return PartialVisitDate(
    date: DateTime(year, month, day),
    precision: VisitDatePrecision.day,
  );
}

Trip trip(String id, String name) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: day(2027, 4, 10),
    endedOn: day(2027, 4, 25),
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
  required FakeTripAssociationRepository repository,
  required List<TripSuggestion> suggestions,
  bool isCountry = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              key: const Key('openSuggestions'),
              onPressed: () {
                showSuggestedTripsDialog(
                  context: context,
                  visitId: 'visit-1',
                  isCountry: isCountry,
                  destinationName: isCountry ? 'Japan' : 'Tokyo',
                  suggestions: suggestions,
                  associationRepository: repository,
                );
              },
              child: const Text('Open suggestions'),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openSuggestions')));

  await tester.pumpAndSettle();
}

void main() {
  group('Suggested Trips dialog', () {
    testWidgets('shows compatible Trips without creating associations', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [
            suggestion('trip-1', 'Japan 2027'),
            suggestion(
              'trip-2',
              'Asia 2027',
              compatibility: TripDateCompatibility.possible,
            ),
          ],
        ),
      );

      await openDialog(tester);

      expect(find.text('Suggested Trips'), findsOneWidget);

      expect(find.text('Japan 2027'), findsOneWidget);

      expect(find.text('Asia 2027'), findsOneWidget);

      expect(find.text('Dates overlap'), findsOneWidget);

      expect(find.text('Possible date match'), findsOneWidget);

      expect(repository.addCountryVisitCalls, 0);
      expect(repository.addCityVisitCalls, 0);
    });

    testWidgets('Done closes dialog without associating the visit', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [suggestion('trip-1', 'Japan 2027')],
        ),
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const Key('finishSuggestedTrips')));

      await tester.pumpAndSettle();

      expect(find.text('Suggested Trips'), findsNothing);

      expect(repository.addCountryVisitCalls, 0);
      expect(repository.addCityVisitCalls, 0);
    });

    testWidgets('explicit action associates correct country visit', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final associations = <(String, String)>[];

      repository.onAddCountryVisit = (tripId, visitId) async {
        associations.add((tripId, visitId));
      };

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [suggestion('trip-1', 'Japan 2027')],
        ),
      );

      await openDialog(tester);

      expect(repository.addCountryVisitCalls, 0);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      expect(associations, [('trip-1', 'visit-1')]);

      expect(repository.addCountryVisitCalls, 1);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('addSuggestedTrip-trip-1')), findsNothing);
    });

    testWidgets('can explicitly associate a visit with two Trips', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final associations = <(String, String)>[];

      repository.onAddCountryVisit = (tripId, visitId) async {
        associations.add((tripId, visitId));
      };

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [
            suggestion('trip-1', 'Japan 2027'),
            suggestion('trip-2', 'Asia 2027'),
          ],
        ),
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-2')));

      await tester.pumpAndSettle();

      expect(associations, [('trip-1', 'visit-1'), ('trip-2', 'visit-1')]);

      expect(repository.addCountryVisitCalls, 2);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-2')),
        findsOneWidget,
      );
    });

    testWidgets('uses city association for a CityVisit', (tester) async {
      final repository = FakeTripAssociationRepository();

      final associations = <(String, String)>[];

      repository.onAddCityVisit = (tripId, visitId) async {
        associations.add((tripId, visitId));
      };

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [suggestion('trip-1', 'Japan 2027')],
          isCountry: false,
        ),
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      expect(associations, [('trip-1', 'visit-1')]);

      expect(repository.addCityVisitCalls, 1);
      expect(repository.addCountryVisitCalls, 0);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );
    });

    testWidgets('association failure allows retry without recreating visit', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final attempts = <(String, String)>[];

      repository.onAddCountryVisit = (tripId, visitId) async {
        attempts.add((tripId, visitId));

        if (attempts.length == 1) {
          throw Exception('Temporary network failure');
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [suggestion('trip-1', 'Japan 2027')],
        ),
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      expect(repository.addCountryVisitCalls, 1);

      expect(
        find.byKey(const Key('suggestedTripError-trip-1')),
        findsOneWidget,
      );

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      expect(repository.addCountryVisitCalls, 2);

      expect(attempts, [('trip-1', 'visit-1'), ('trip-1', 'visit-1')]);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('suggestedTripError-trip-1')), findsNothing);
    });

    testWidgets('prevents duplicate actions while association is pending', (
      tester,
    ) async {
      final repository = FakeTripAssociationRepository();

      final pending = Completer<void>();

      repository.onAddCountryVisit = (tripId, visitId) {
        return pending.future;
      };

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [
            suggestion('trip-1', 'Japan 2027'),
            suggestion('trip-2', 'Asia 2027'),
          ],
        ),
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pump();

      expect(repository.addCountryVisitCalls, 1);

      final doneFinder = find.byKey(const Key('finishSuggestedTrips'));

      final addFinder = find.byKey(const Key('addSuggestedTrip-trip-2'));

      if (Theme.of(tester.element(doneFinder)).platform == TargetPlatform.iOS) {
        final doneButton = tester.widget<CupertinoButton>(doneFinder);
        final addButton = tester.widget<CupertinoButton>(addFinder);

        expect(doneButton.onPressed, isNull);
        expect(addButton.onPressed, isNull);
      } else {
        final doneButton = tester.widget<FilledButton>(doneFinder);
        final addButton = tester.widget<TextButton>(addFinder);

        expect(doneButton.onPressed, isNull);
        expect(addButton.onPressed, isNull);
      }

      // The original association finishes.
      pending.complete();

      await tester.pumpAndSettle();

      expect(repository.addCountryVisitCalls, 1);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );
    });

    testWidgets('does not open when there are no suggestions', (tester) async {
      final repository = FakeTripAssociationRepository();

      await tester.pumpWidget(
        buildTestApp(repository: repository, suggestions: const []),
      );

      await tester.tap(find.byKey(const Key('openSuggestions')));

      await tester.pumpAndSettle();

      expect(find.text('Suggested Trips'), findsNothing);

      expect(repository.addCountryVisitCalls, 0);
      expect(repository.addCityVisitCalls, 0);
    });
  });
  testWidgets('uses Cupertino presentation on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      final repository = FakeTripAssociationRepository();

      repository.onAddCountryVisit = (tripId, visitId) async {};

      await tester.pumpWidget(
        buildTestApp(
          repository: repository,
          suggestions: [suggestion('trip-1', 'Japan 2027')],
        ),
      );

      await openDialog(tester);

      expect(find.byType(CupertinoPopupSurface), findsOneWidget);

      expect(
        find.byKey(const Key('materialSuggestedTripsDialog')),
        findsNothing,
      );

      expect(find.byKey(const Key('addSuggestedTrip-trip-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('addSuggestedTrip-trip-1')));

      await tester.pumpAndSettle();

      expect(repository.addCountryVisitCalls, 1);

      expect(
        find.byKey(const Key('suggestedTripAdded-trip-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('finishSuggestedTrips')));

      await tester.pumpAndSettle();

      expect(find.byType(CupertinoPopupSurface), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
