import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_cubit.dart';
import 'package:beenaround/features/explore/domain/visited_city.dart';
import 'package:beenaround/features/explore/presentation/widgets/edit_city_visit_sheet.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int updateCalls = 0;
  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CityVisit> Function()? updateHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    return makeVisit(
      startedOn: changes['started_on'] as DateTime?,
      endedOn: changes['ended_on'] as DateTime?,
    );
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

CityVisit makeVisit({
  DateTime? startedOn,
  DateTime? endedOn,
  VisitDatePrecision? startedOnPrecision,
  VisitDatePrecision? endedOnPrecision,
}) {
  return CityVisit(
    id: 'visit-1',
    cityId: 2267057,
    cityName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    startedOn: startedOn,
    endedOn: endedOn,
    startedOnPrecision: startedOnPrecision,
    endedOnPrecision: endedOnPrecision,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  Future<EditCityVisitCubit> pumpSheet(
    WidgetTester tester, {
    required FakeCityVisitsRepository repository,
    required CityVisit visit,
  }) async {
    final cubit = EditCityVisitCubit(repository: repository);

    final city = VisitedCity(
      cityId: visit.cityId,
      cityName: visit.cityName,
      countryCode: visit.countryCode,
      countryName: visit.countryName,
      visits: [visit],
    );

    await tester.pumpWidget(
      BlocProvider<EditCityVisitCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: EditCityVisitSheet(city: city, visit: visit),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    addTearDown(cubit.close);

    return cubit;
  }

  testWidgets('displays existing dates', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      ),
    );

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);
  });

  testWidgets('clears start date without clearing end date', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      ),
    );

    await tester.tap(find.byKey(const Key('editCityVisitClearStartDate')));

    await tester.pumpAndSettle();

    expect(find.text('10/10/2026'), findsNothing);
    expect(find.text('15/10/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    expect(repository.receivedChanges, {
      'started_on': null,
      'started_on_precision': null,
    });
  });

  testWidgets('clears end date without clearing start date', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      ),
    );

    await tester.tap(find.byKey(const Key('editCityVisitClearEndDate')));

    await tester.pumpAndSettle();

    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsNothing);

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    expect(repository.receivedChanges, {
      'ended_on': null,
      'ended_on_precision': null,
    });
  });

  testWidgets('supports visits with only an end date', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(endedOn: DateTime(2025, 6, 15)),
    );

    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('15/06/2025'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 0);
    expect(repository.receivedChanges, isNull);
  });

  testWidgets('disables save while submitting', (tester) async {
    final repository = FakeCityVisitsRepository();
    final pending = Completer<CityVisit>();

    repository.updateHandler = () => pending.future;

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(startedOn: DateTime(2026, 10, 10)),
    );

    await tester.tap(find.byKey(const Key('editCityVisitClearStartDate')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pump();

    expect(find.text('Saving...'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('editCityVisitSaveButton')),
    );

    expect(saveButton.onPressed, isNull);
    expect(repository.updateCalls, 1);

    pending.complete(makeVisit());

    await tester.pumpAndSettle();
  });
  testWidgets('displays month precision correctly', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.month,
      ),
    );

    expect(find.text('January 2024'), findsOneWidget);
    expect(find.text('01/01/2024'), findsNothing);
  });
  testWidgets('displays year precision correctly', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
      ),
    );

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('01/01/2024'), findsNothing);
  });
  testWidgets('clearing end date preserves existing start precision', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOn: DateTime(2024, 2, 1),
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await tester.tap(find.byKey(const Key('editCityVisitClearEndDate')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    expect(repository.receivedChanges, {
      'ended_on': null,
      'ended_on_precision': null,
    });

    expect(repository.receivedChanges!.containsKey('started_on'), isFalse);

    expect(
      repository.receivedChanges!.containsKey('started_on_precision'),
      isFalse,
    );
  });
}
