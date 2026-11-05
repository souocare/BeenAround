import 'dart:async';

import 'package:beenaround/core/network/api_exception.dart';

import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/domain/trip_input.dart';
import 'package:beenaround/features/trips/domain/trip_repository.dart';

import 'package:beenaround/features/trips/presentation/widgets/delete_trip_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDeleteTripRepository implements TripRepository {
  int deleteCalls = 0;
  String? lastDeletedId;

  Future<void> Function(String tripId)? onDelete;

  @override
  Future<void> deleteTrip({required String tripId}) {
    deleteCalls++;
    lastDeletedId = tripId;

    final handler = onDelete;

    if (handler != null) {
      return handler(tripId);
    }

    return Future.value();
  }

  @override
  Future<List<Trip>> getTrips() async => const [];

  @override
  Future<Trip> getTrip({required String tripId}) {
    throw UnimplementedError();
  }

  @override
  Future<Trip> createTrip({required TripInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<Trip> updateTrip({required String tripId, required TripInput input}) {
    throw UnimplementedError();
  }
}

Trip testTrip() {
  return Trip(
    id: 'trip-1',
    name: 'Japan 2027',
    description: null,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget buildTestApp(TripRepository repository, {ValueChanged<bool>? onResult}) {
  return RepositoryProvider<TripRepository>.value(
    value: repository,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  final deleted = await showDeleteTripDialog(
                    context: context,
                    trip: testTrip(),
                  );

                  onResult?.call(deleted);
                },
                child: const Text('Open Delete Dialog'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('displays Trip name and deletion warning', (tester) async {
    final repository = FakeDeleteTripRepository();

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Trip?'), findsOneWidget);

    expect(find.textContaining('Japan 2027'), findsOneWidget);

    expect(find.textContaining('will not be deleted'), findsOneWidget);
  });

  testWidgets('cancel does not delete the Trip', (tester) async {
    final repository = FakeDeleteTripRepository();

    bool? result;

    await tester.pumpWidget(
      buildTestApp(repository, onResult: (value) => result = value),
    );

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancelDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(result, isFalse);
    expect(find.text('Delete Trip?'), findsNothing);
  });

  testWidgets('confirms and deletes the correct Trip', (tester) async {
    final repository = FakeDeleteTripRepository();

    bool? result;

    await tester.pumpWidget(
      buildTestApp(repository, onResult: (value) => result = value),
    );

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.lastDeletedId, 'trip-1');

    expect(result, isTrue);
    expect(find.text('Delete Trip?'), findsNothing);
  });

  testWidgets('prevents duplicate deletion requests', (tester) async {
    final repository = FakeDeleteTripRepository();
    final pending = Completer<void>();

    repository.onDelete = (_) => pending.future;

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pump();

    expect(repository.deleteCalls, 1);

    final deleteButton = tester.widget<FilledButton>(
      find.byKey(const Key('confirmDeleteTripButton')),
    );

    expect(deleteButton.onPressed, isNull);

    final cancelButton = tester.widget<TextButton>(
      find.byKey(const Key('cancelDeleteTripButton')),
    );

    expect(cancelButton.onPressed, isNull);

    pending.complete();

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('Delete Trip?'), findsNothing);
  });

  testWidgets('displays API errors and allows retry', (tester) async {
    final repository = FakeDeleteTripRepository();

    var attempts = 0;

    repository.onDelete = (_) async {
      attempts++;

      if (attempts == 1) {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'The server encountered an error.',
          statusCode: 500,
        );
      }
    };

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(find.text('The server encountered an error.'), findsOneWidget);

    expect(repository.deleteCalls, 1);

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 2);
    expect(find.text('Delete Trip?'), findsNothing);
  });

  testWidgets('unexpected exceptions show a safe message', (tester) async {
    final repository = FakeDeleteTripRepository();

    repository.onDelete = (_) async {
      throw StateError('Internal database details');
    };

    await tester.pumpWidget(buildTestApp(repository));

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));

    await tester.pumpAndSettle();

    expect(
      find.text('Unable to delete this Trip. Please try again.'),
      findsOneWidget,
    );

    expect(find.text('Delete Trip?'), findsOneWidget);
  });
}
