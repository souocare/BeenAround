import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_form_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/models/partial_visit_date.dart';

class FakeTripFormRepository implements TripRepository {
  int createCalls = 0;
  int updateCalls = 0;

  TripInput? lastInput;
  String? lastUpdatedId;

  @override
  Future<Trip> createTrip({required TripInput input}) async {
    createCalls++;
    lastInput = input;

    return _trip(
      id: 'created-trip',
      name: input.name,
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
    );
  }

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required TripInput input,
  }) async {
    updateCalls++;
    lastUpdatedId = tripId;
    lastInput = input;

    return _trip(
      id: tripId,
      name: input.name,
      description: input.description,
      startedOn: input.startedOn,
      endedOn: input.endedOn,
    );
  }

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<Trip> getTrip({required String tripId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTrip({required String tripId}) {
    throw UnimplementedError();
  }
}

Trip _trip({
  required String id,
  required String name,
  String? description,
  PartialVisitDate? startedOn,
  PartialVisitDate? endedOn,
}) {
  return Trip(
    id: id,
    name: name,
    description: description,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget buildTestApp(TripRepository repository, {Trip? existingTrip}) {
  return RepositoryProvider<TripRepository>.value(
    value: repository,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  showTripFormDialog(context: context, trip: existingTrip);
                },
                child: const Text('Open Form'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> tapSaveTrip(WidgetTester tester) async {
  final button = find.byKey(const Key('saveTripButton'));

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> tapCancelTrip(WidgetTester tester) async {
  final button = find.widgetWithText(TextButton, 'Cancel');

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens Create Trip form', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    expect(find.text('New Trip'), findsOneWidget);
    expect(find.byKey(const Key('tripNameField')), findsOneWidget);
    expect(find.byKey(const Key('tripDescriptionField')), findsOneWidget);
    expect(find.byKey(const Key('saveTripButton')), findsOneWidget);
  });

  testWidgets('creates a Trip without dates', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan 2027',
    );

    await tapSaveTrip(tester);

    expect(repository.createCalls, 1);
    expect(repository.lastInput?.name, 'Japan 2027');

    expect(repository.lastInput?.startedOn, isNull);
    expect(repository.lastInput?.endedOn, isNull);

    expect(find.text('New Trip'), findsNothing);
  });

  testWidgets('rejects an empty Trip name', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tapSaveTrip(tester);

    expect(find.text('Enter a Trip name.'), findsOneWidget);

    expect(repository.createCalls, 0);
  });

  testWidgets('opens Edit Trip with existing values', (tester) async {
    final repository = FakeTripFormRepository();

    final existingTrip = _trip(
      id: 'trip-1',
      name: 'Japan 2027',
      description: 'Spring holiday',
    );

    await tester.pumpWidget(
      buildTestApp(repository, existingTrip: existingTrip),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Trip'), findsOneWidget);

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('tripNameField')),
    );

    expect(nameField.controller?.text, 'Japan 2027');

    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const Key('tripDescriptionField')),
    );

    expect(descriptionField.controller?.text, 'Spring holiday');
  });

  testWidgets('updates an existing Trip', (tester) async {
    final repository = FakeTripFormRepository();

    final existingTrip = _trip(id: 'trip-1', name: 'Japan 2027');

    await tester.pumpWidget(
      buildTestApp(repository, existingTrip: existingTrip),
    );

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tripNameField')),
      'Japan & Korea 2027',
    );

    await tapSaveTrip(tester);

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 1);

    expect(repository.lastUpdatedId, 'trip-1');
    expect(repository.lastInput?.name, 'Japan & Korea 2027');
  });

  testWidgets('cancel does not persist changes', (tester) async {
    final repository = FakeTripFormRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tapCancelTrip(tester);

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 0);

    expect(find.text('New Trip'), findsNothing);
  });
}
