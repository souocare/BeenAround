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

  testWidgets('clears only the start date', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOn: DateTime(2024, 3, 1),
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await tester.tap(find.byKey(const Key('editVisitClearStartDate')));
    await tester.pumpAndSettle();

    expect(find.text('March 2024'), findsOneWidget);
    expect(find.text('January 2024'), findsNothing);

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedChanges, {
      'started_on': null,
      'started_on_precision': null,
    });
  });

  testWidgets('clears only the end date', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOn: DateTime(2024, 3, 1),
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await tester.tap(find.byKey(const Key('editVisitClearEndDate')));
    await tester.pumpAndSettle();

    expect(find.text('January 2024'), findsOneWidget);
    expect(find.text('March 2024'), findsNothing);

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedChanges, {
      'ended_on': null,
      'ended_on_precision': null,
    });
  });

  testWidgets('clears both dates', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        startedOnPrecision: VisitDatePrecision.year,
        endedOn: DateTime(2025, 1, 1),
        endedOnPrecision: VisitDatePrecision.year,
      ),
    );

    await tester.tap(find.byKey(const Key('editVisitClearDates')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.receivedChanges, {
      'started_on': null,
      'started_on_precision': null,
      'ended_on': null,
      'ended_on_precision': null,
    });
  });

  testWidgets('does not submit unchanged visits', (tester) async {
    final repository = FakeCountriesRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(endedOn: DateTime(2025, 6, 15)),
    );

    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('15/06/2025'), findsOneWidget);

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
      visit: makeVisit(startedOn: DateTime(2026, 10, 10)),
    );

    await tester.tap(find.byKey(const Key('editVisitClearStartDate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pump();

    expect(find.text('Saving...'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('editVisitSaveButton')),
    );

    expect(saveButton.onPressed, isNull);
    expect(repository.updateCalls, 1);

    pending.complete(makeVisit());
    await tester.pumpAndSettle();
  });
}
