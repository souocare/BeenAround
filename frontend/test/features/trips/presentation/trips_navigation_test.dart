import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';

import 'package:beenaround/features/trips/presentation/pages/trips_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryTripRepository implements TripRepository {
  InMemoryTripRepository({List<Trip> initialTrips = const []})
    : _trips = {for (final trip in initialTrips) trip.id: trip};

  final Map<String, Trip> _trips;

  int listCalls = 0;
  int detailCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  bool failNextDetailRequest = false;

  @override
  Future<List<Trip>> getTrips() async {
    listCalls++;

    return List.unmodifiable(_trips.values);
  }

  @override
  Future<Trip> getTrip({required String tripId}) async {
    detailCalls++;

    if (failNextDetailRequest) {
      failNextDetailRequest = false;

      throw const ApiException(
        type: ApiErrorType.server,
        message: 'The server encountered an error.',
        statusCode: 500,
      );
    }

    return _findTrip(tripId);
  }

  @override
  Future<Trip> createTrip({required TripInput input}) async {
    input.toJson();

    final id = 'trip-${_trips.length + 1}';

    final trip = Trip(
      id: id,
      name: input.name.trim(),
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
      createdAt: DateTime(2026, 11, 5),
      updatedAt: DateTime(2026, 11, 5),
    );

    _trips[id] = trip;

    return trip;
  }

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required TripInput input,
  }) async {
    input.toJson();

    final existing = _findTrip(tripId);

    updateCalls++;

    final updated = Trip(
      id: existing.id,
      name: input.name.trim(),
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 11, 6),
    );

    _trips[tripId] = updated;

    return updated;
  }

  @override
  Future<void> deleteTrip({required String tripId}) async {
    _findTrip(tripId);

    deleteCalls++;

    _trips.remove(tripId);
  }

  Trip _findTrip(String id) {
    final trip = _trips[id];

    if (trip == null) {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'The requested resource was not found.',
        statusCode: 404,
      );
    }

    return trip;
  }

  bool containsTrip(String id) => _trips.containsKey(id);
}

Trip sampleTrip({
  required String id,
  required String name,
  String? description,
}) {
  return Trip(
    id: id,
    name: name,
    description: description,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 11, 5),
    updatedAt: DateTime(2026, 11, 5),
  );
}

Widget buildTestApp(TripRepository repository) {
  return RepositoryProvider<TripRepository>.value(
    value: repository,
    child: const MaterialApp(home: Scaffold(body: TripsPage())),
  );
}

Future<void> openTrip(WidgetTester tester, String tripId) async {
  final card = find.byKey(Key('tripCard-$tripId'));

  await tester.ensureVisible(card);
  await tester.pumpAndSettle();

  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> tapSaveTrip(WidgetTester tester) async {
  final button = find.byKey(const Key('saveTripButton'));

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Trips navigation integration', () {
    testWidgets('opens the selected Trip and loads its details', (
      tester,
    ) async {
      final repository = InMemoryTripRepository(
        initialTrips: [
          sampleTrip(
            id: 'trip-1',
            name: 'Japan 2027',
            description: 'Spring holiday',
          ),
          sampleTrip(id: 'trip-2', name: 'Italy 2026'),
        ],
      );

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('Japan 2027'), findsOneWidget);
      expect(find.text('Italy 2026'), findsOneWidget);

      await openTrip(tester, 'trip-1');

      expect(find.text('Trip Details'), findsOneWidget);

      expect(find.byKey(const Key('tripDetailsName')), findsOneWidget);

      expect(find.text('Japan 2027'), findsOneWidget);
      expect(find.text('Spring holiday'), findsOneWidget);
      expect(find.text('Dates not specified'), findsOneWidget);

      expect(repository.detailCalls, 1);
    });

    testWidgets('editing details updates the Trip and refreshes the list', (
      tester,
    ) async {
      final repository = InMemoryTripRepository(
        initialTrips: [sampleTrip(id: 'trip-1', name: 'Japan 2027')],
      );

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      await openTrip(tester, 'trip-1');

      await tester.tap(find.byKey(const Key('editTripDetailsButton')));

      await tester.pumpAndSettle();

      expect(find.text('Edit Trip'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('tripNameField')),
        'Japan & Korea 2027',
      );

      await tapSaveTrip(tester);

      expect(repository.updateCalls, 1);

      expect(find.text('Japan & Korea 2027'), findsOneWidget);

      // Return to the Trips list.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Trips'), findsOneWidget);

      expect(find.text('Japan & Korea 2027'), findsOneWidget);

      expect(repository.listCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('deleting a Trip returns to the refreshed list', (
      tester,
    ) async {
      final repository = InMemoryTripRepository(
        initialTrips: [
          sampleTrip(id: 'trip-1', name: 'Japan 2027'),
          sampleTrip(id: 'trip-2', name: 'Italy 2026'),
        ],
      );

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      await openTrip(tester, 'trip-1');

      await tester.tap(find.byKey(const Key('deleteTripDetailsButton')));

      await tester.pumpAndSettle();

      expect(find.text('Delete Trip?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 1);
      expect(repository.containsTrip('trip-1'), isFalse);

      expect(find.text('Trip Details'), findsNothing);

      expect(find.byKey(const Key('tripCard-trip-1')), findsNothing);

      expect(find.byKey(const Key('tripCard-trip-2')), findsOneWidget);

      expect(find.text('Italy 2026'), findsOneWidget);

      expect(repository.listCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('detail loading errors can be retried', (tester) async {
      final repository = InMemoryTripRepository(
        initialTrips: [sampleTrip(id: 'trip-1', name: 'Japan 2027')],
      );

      repository.failNextDetailRequest = true;

      await tester.pumpWidget(buildTestApp(repository));
      await tester.pumpAndSettle();

      await openTrip(tester, 'trip-1');

      expect(find.text('The server encountered an error.'), findsOneWidget);

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Japan 2027'), findsOneWidget);

      expect(find.byKey(const Key('tripDetailsName')), findsOneWidget);

      expect(repository.detailCalls, 2);
    });
  });
}
