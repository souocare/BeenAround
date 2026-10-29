import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/edit_country_visit_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/widgets/edit_country_visit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountriesRepository implements CountriesRepository {
  int updateCalls = 0;
  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CountryVisit> Function()? updateHandler;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async => const [];

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError();
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map<String, dynamic>.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    return Future.value(
      makeVisit(
        startedOn: changes['started_on'] as DateTime?,
        endedOn: changes['ended_on'] as DateTime?,
        startedOnPrecision:
            changes['started_on_precision'] as VisitDatePrecision?,
        endedOnPrecision: changes['ended_on_precision'] as VisitDatePrecision?,
      ),
    );
  }
}

const portugal = Country(
  code: 'PT',
  name: 'Portugal',
  alpha3Code: 'PRT',
  continent: 'Europe',
);

CountryVisit makeVisit({
  DateTime? startedOn,
  DateTime? endedOn,
  VisitDatePrecision? startedOnPrecision,
  VisitDatePrecision? endedOnPrecision,
}) {
  return CountryVisit(
    id: 'visit-1',
    countryCode: 'PT',
    startedOn: startedOn,
    endedOn: endedOn,
    startedOnPrecision: startedOnPrecision,
    endedOnPrecision: endedOnPrecision,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required FakeCountriesRepository repository,
    required CountryVisit visit,
  }) async {
    final cubit = EditCountryVisitCubit(repository: repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<EditCountryVisitCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: EditCountryVisitSheet(country: portugal, visit: visit),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('displays legacy exact dates', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      ),
    );

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);
  });

  testWidgets('displays month precision', (tester) async {
    final repository = FakeCountriesRepository();

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

  testWidgets('displays year precision', (tester) async {
    final repository = FakeCountriesRepository();

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

  testWidgets('does not expose date clearing actions', (tester) async {
    final repository = FakeCountriesRepository();

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

    expect(find.byKey(const Key('editVisitClearStartDate')), findsNothing);

    expect(find.byKey(const Key('editVisitClearEndDate')), findsNothing);

    expect(find.byKey(const Key('editVisitClearDates')), findsNothing);

    expect(find.text('January 2024'), findsOneWidget);
    expect(find.text('March 2024'), findsOneWidget);
  });

  testWidgets('does not submit unchanged visits', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2025, 6, 10),
        endedOn: DateTime(2025, 6, 15),
        startedOnPrecision: VisitDatePrecision.day,
        endedOnPrecision: VisitDatePrecision.day,
      ),
    );

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 0);
    expect(repository.receivedChanges, isNull);
  });

  testWidgets('disables save while submitting', (tester) async {
    final repository = FakeCountriesRepository();
    final pending = Completer<CountryVisit>();

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
    await tester.tap(find.byKey(const Key('editVisitStartDate')));
    await tester.pumpAndSettle();

    expect(find.text('How precise is your date?'), findsOneWidget);

    // Keep month precision.
    await tester.tap(find.text('Month and year'));
    await tester.pumpAndSettle();

    expect(find.text('Select month and year'), findsOneWidget);

    // Change January to February.
    final monthDropdown = find.byType(DropdownButton<int>).last;

    await tester.tap(monthDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('February 2024').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify the date changed without modifying the end date.
    expect(find.text('February 2024'), findsOneWidget);
    expect(find.text('March 2024'), findsOneWidget);

    // Submit the update.
    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pump();

    expect(repository.updateCalls, 1);

    // Only the start date should be included in PATCH.
    expect(repository.receivedChanges, {
      'started_on': DateTime(2024, 2, 1),
      'started_on_precision': VisitDatePrecision.month,
    });

    expect(find.text('Saving...'), findsOneWidget);

    // Save must be disabled while submitting.
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('editVisitSaveButton')),
    );

    expect(saveButton.onPressed, isNull);

    // Date editing must also be disabled.
    final startDateTile = tester.widget<ListTile>(
      find.byKey(const Key('editVisitStartDate')),
    );

    final endDateTile = tester.widget<ListTile>(
      find.byKey(const Key('editVisitEndDate')),
    );

    expect(startDateTile.onTap, isNull);
    expect(endDateTile.onTap, isNull);

    // Finish the pending request.
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
}
