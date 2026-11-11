import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/presentation/pages/trips_page.dart';

class FakeTripRepository implements TripRepository {
  FakeTripRepository({List<Trip> trips = const [], this.shouldFail = false})
    : trips = List.of(trips);

  final List<Trip> trips;
  final bool shouldFail;

  int deleteCalls = 0;
  String? lastDeletedId;

  bool failDeletion = false;

  @override
  Future<List<Trip>> getTrips() async {
    if (shouldFail) {
      throw Exception('Unable to load');
    }

    return trips;
  }

  @override
  Future<Trip> getTrip({required String tripId}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Trip>> getTripsForCountry({required String countryCode}) {
    throw UnimplementedError('Country Trips are not exercised by this test.');
  }

  @override
  Future<List<Trip>> getTripsForCity({required int cityId}) {
    throw UnimplementedError('City Trips are not exercised by this test.');
  }

  @override
  Future<Trip> createTrip({required TripInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<Trip> updateTrip({required String tripId, required TripInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip({required String tripId}) async {
    deleteCalls++;
    lastDeletedId = tripId;

    if (failDeletion) {
      throw Exception('Unable to delete Trip.');
    }

    trips.removeWhere((trip) => trip.id == tripId);
  }
}

Trip testTrip({required String id, required String name}) {
  return Trip(
    id: id,
    name: name,
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget buildTestApp(TripRepository repository) {
  return RepositoryProvider<TripRepository>.value(
    value: repository,
    child: const MaterialApp(home: Scaffold(body: TripsPage())),
  );
}

void main() {
  testWidgets('shows empty state when there are no Trips', (tester) async {
    final repository = FakeTripRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    expect(find.text('Your journeys start here'), findsOneWidget);

    expect(find.text('Create Trip'), findsWidgets);
  });

  testWidgets('shows Trips returned by repository', (tester) async {
    final repository = FakeTripRepository(
      trips: [
        testTrip(id: '1', name: 'Japan 2027'),
        testTrip(id: '2', name: 'Italy 2026'),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    expect(find.text('Japan 2027'), findsOneWidget);

    expect(find.text('Italy 2026'), findsOneWidget);

    expect(find.byKey(const Key('tripCard-1')), findsOneWidget);

    expect(find.byKey(const Key('tripCard-2')), findsOneWidget);
  });

  testWidgets('search filters Trips by name', (tester) async {
    final repository = FakeTripRepository(
      trips: [
        testTrip(id: '1', name: 'Japan 2027'),
        testTrip(id: '2', name: 'Italy 2026'),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tripsSearchField')), 'japan');

    await tester.pumpAndSettle();

    expect(find.text('Japan 2027'), findsOneWidget);

    expect(find.text('Italy 2026'), findsNothing);
  });

  testWidgets('shows no results for unmatched search', (tester) async {
    final repository = FakeTripRepository(
      trips: [testTrip(id: '1', name: 'Japan 2027')],
    );

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tripsSearchField')), 'Brazil');

    await tester.pumpAndSettle();

    expect(find.text('No matching trips'), findsOneWidget);
  });

  testWidgets('shows retry option when loading fails', (tester) async {
    final repository = FakeTripRepository(shouldFail: true);

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    expect(find.text('Unable to load Trips'), findsOneWidget);

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders all four status filters', (tester) async {
    final repository = FakeTripRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripsFilter-all')), findsOneWidget);

    expect(find.byKey(const Key('tripsFilter-upcoming')), findsOneWidget);

    expect(find.byKey(const Key('tripsFilter-ongoing')), findsOneWidget);

    expect(find.byKey(const Key('tripsFilter-completed')), findsOneWidget);
  });
  testWidgets('Trip cards expose a delete action', (tester) async {
    final repository = FakeTripRepository(
      trips: [testTrip(id: 'trip-1', name: 'Honeymoon')],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCard-trip-1')), findsOneWidget);

    expect(find.byKey(const Key('editTrip-trip-1')), findsOneWidget);

    expect(find.byKey(const Key('deleteTrip-trip-1')), findsOneWidget);

    expect(repository.deleteCalls, 0);
  });
  testWidgets('cancelling deletion keeps the Trip', (tester) async {
    final repository = FakeTripRepository(
      trips: [testTrip(id: 'trip-1', name: 'Honeymoon')],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTrip-trip-1')));

    await tester.pumpAndSettle();

    expect(find.text('Delete Trip?'), findsOneWidget);

    expect(repository.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('cancelDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(repository.trips.length, 1);

    expect(find.byKey(const Key('tripCard-trip-1')), findsOneWidget);
  });
  testWidgets('confirming deletion removes the Trip from the list', (
    tester,
  ) async {
    final repository = FakeTripRepository(
      trips: [
        testTrip(id: 'trip-1', name: 'Honeymoon'),
        testTrip(id: 'trip-2', name: 'Italy 2026'),
      ],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tripCard-trip-1')), findsOneWidget);

    expect(find.byKey(const Key('tripCard-trip-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteTrip-trip-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'trip-1');

    expect(repository.trips.map((trip) => trip.id), ['trip-2']);

    expect(find.byKey(const Key('tripCard-trip-1')), findsNothing);

    expect(find.byKey(const Key('tripCard-trip-2')), findsOneWidget);

    expect(find.text('Italy 2026'), findsOneWidget);
    expect(find.text('Honeymoon'), findsNothing);
  });
  testWidgets('failed deletion preserves the Trip and allows retry', (
    tester,
  ) async {
    final repository = FakeTripRepository(
      trips: [testTrip(id: 'trip-1', name: 'Honeymoon')],
    )..failDeletion = true;

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTrip-trip-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);

    expect(find.byKey(const Key('deleteTripError')), findsOneWidget);

    expect(find.byKey(const Key('tripCard-trip-1')), findsOneWidget);

    // Simulate backend recovery.
    repository.failDeletion = false;

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 2);

    expect(find.byKey(const Key('tripCard-trip-1')), findsNothing);
  });
}
