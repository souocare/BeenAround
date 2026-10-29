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

  testWidgets('disables save while submitting', (tester) async {
    final repository = FakeCityVisitsRepository();
    final pending = Completer<CityVisit>();

    repository.updateHandler = () => pending.future;

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    // Open the start date picker.
    await tester.tap(find.byKey(const Key('editCityVisitStartDate')));
    await tester.pumpAndSettle();

    expect(find.text('How precise is your date?'), findsOneWidget);

    // Select month precision.
    await tester.tap(find.text('Month and year'));
    await tester.pumpAndSettle();

    expect(find.text('Select month and year'), findsOneWidget);

    // Change the start month to February.
    final monthDropdown = find.byType(DropdownButton<int>).last;

    await tester.tap(monthDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('February 2024').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify both displayed dates.
    expect(find.text('February 2024'), findsOneWidget);
    expect(find.text('March 2024'), findsOneWidget);

    // Submit.
    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));
    await tester.pump();

    expect(repository.updateCalls, 1);

    // PATCH must preserve the existing end date.
    expect(repository.receivedChanges, {
      'started_on': DateTime(2024, 2, 1),
      'started_on_precision': VisitDatePrecision.month,
    });

    expect(find.text('Saving...'), findsOneWidget);

    // Save must be disabled.
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('editCityVisitSaveButton')),
    );

    expect(saveButton.onPressed, isNull);

    // Both date fields must be disabled.
    final startDateTile = tester.widget<ListTile>(
      find.byKey(const Key('editCityVisitStartDate')),
    );

    final endDateTile = tester.widget<ListTile>(
      find.byKey(const Key('editCityVisitEndDate')),
    );

    expect(startDateTile.onTap, isNull);
    expect(endDateTile.onTap, isNull);

    // Complete the request.
    pending.complete(
      makeVisit(
        startedOn: DateTime(2024, 2, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await tester.pumpAndSettle();
  });
  testWidgets('displays month precision correctly', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
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
        endedOn: DateTime(2025, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOnPrecision: VisitDatePrecision.year,
      ),
    );

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('01/01/2024'), findsNothing);
  });

  testWidgets('does not expose date clearing actions', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    expect(find.byKey(const Key('editCityVisitClearStartDate')), findsNothing);

    expect(find.byKey(const Key('editCityVisitClearEndDate')), findsNothing);

    expect(find.text('January 2024'), findsOneWidget);
    expect(find.text('March 2024'), findsOneWidget);
  });
}
