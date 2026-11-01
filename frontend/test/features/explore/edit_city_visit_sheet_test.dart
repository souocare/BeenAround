import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_cubit.dart';
import 'package:beenaround/features/explore/domain/visited_city.dart';
import 'package:beenaround/features/explore/presentation/widgets/edit_city_visit_sheet.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/explore/application/edit_city_visit_state.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int updateCalls = 0;
  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CityVisit> Function()? updateHandler;
  CountryVisitDateExpansion? expansionOnFirstUpdate;

  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map<String, dynamic>.of(changes);

    // Simulate the backend requesting explicit confirmation.
    // The first PATCH does not persist any changes.
    if (updateCalls == 1 && expansionOnFirstUpdate != null) {
      throw CountryVisitDateExpansionRequired(expansionOnFirstUpdate!);
    }

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

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({List<CountryVisit> visits = const []})
    : visits = List.of(visits);

  final List<CountryVisit> visits;

  int getCountryVisitsCalls = 0;

  @override
  Future<List<Country>> getCountries() async => const [];

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    getCountryVisitsCalls++;
    return List.unmodifiable(visits);
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

CityVisit makeVisit({
  DateTime? startedOn,
  DateTime? endedOn,
  VisitDatePrecision? startedOnPrecision,
  VisitDatePrecision? endedOnPrecision,
  String? countryVisitId,
}) {
  return CityVisit(
    id: 'visit-1',
    cityId: 2267057,
    cityName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    countryVisitId: countryVisitId,
    startedOn: startedOn,
    endedOn: endedOn,
    startedOnPrecision: startedOnPrecision,
    endedOnPrecision: endedOnPrecision,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 24),
  );
}

CountryVisit makeCountryVisit({
  required String id,
  String countryCode = 'PT',
  int year = 2024,
  int startMonth = 1,
  int endMonth = 3,
}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: DateTime(year, startMonth, 1),
    endedOn: DateTime(year, endMonth, 1),
    startedOnPrecision: VisitDatePrecision.month,
    endedOnPrecision: VisitDatePrecision.month,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 24),
  );
}

CountryVisitDateExpansion sampleDateExpansion() {
  return CountryVisitDateExpansion.fromJson({
    'country_visit_id': '550e8400-e29b-41d4-a716-446655440001',
    'current': {
      'started_on': '2024-01-01',
      'started_on_precision': 'month',
      'ended_on': '2024-03-01',
      'ended_on_precision': 'month',
    },
    'proposed': {
      'started_on': '2024-01-01',
      'started_on_precision': 'month',
      'ended_on': '2024-04-01',
      'ended_on_precision': 'month',
    },
  });
}

Future<void> changeCityVisitEndMonth(
  WidgetTester tester, {
  required String monthLabel,
}) async {
  await tester.tap(find.byKey(const Key('editCityVisitEndDate')));

  await tester.pumpAndSettle();

  await tester.tap(find.text('Month and year'));
  await tester.pumpAndSettle();

  expect(find.text('Select month and year'), findsOneWidget);

  final monthDropdown = find.byType(DropdownButton<int>).last;

  await tester.tap(monthDropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(monthLabel).last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> tapEditAssociationOption(WidgetTester tester, String key) async {
  final option = find.byKey(Key(key));

  await tester.scrollUntilVisible(
    option,
    150,
    scrollable: find.byType(Scrollable).last,
  );

  await tester.pumpAndSettle();

  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  Future<EditCityVisitCubit> pumpSheet(
    WidgetTester tester, {
    required FakeCityVisitsRepository repository,
    required CityVisit visit,
    List<CountryVisit> countryVisits = const [],
  }) async {
    final cubit = EditCityVisitCubit(repository: repository);

    final city = VisitedCity(
      cityId: visit.cityId,
      cityName: visit.cityName,
      countryCode: visit.countryCode,
      countryName: visit.countryName,
      visits: [visit],
    );
    final countriesRepository = FakeCountriesRepository(visits: countryVisits);

    await tester.pumpWidget(
      RepositoryProvider<CountriesRepository>.value(
        value: countriesRepository,
        child: BlocProvider<EditCityVisitCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: EditCityVisitSheet(city: city, visit: visit),
            ),
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
  testWidgets(
    'shows expansion dialog when updating city dates requires confirmation',
    (tester) async {
      final expansion = sampleDateExpansion();

      final repository = FakeCityVisitsRepository()
        ..expansionOnFirstUpdate = expansion;

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

      await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(find.text('Extend country visit dates?'), findsOneWidget);

      expect(
        find.byKey(const Key('countryExpansionCurrentDates')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('countryExpansionProposedDates')),
        findsOneWidget,
      );

      // Only the initial PATCH has been sent.
      expect(repository.updateCalls, 1);

      expect(repository.receivedVisitId, 'visit-1');

      expect(repository.receivedChanges, {
        'ended_on': DateTime(2024, 4, 1),
        'ended_on_precision': VisitDatePrecision.month,
      });

      // PATCH preserves the existing association.
      expect(
        repository.receivedChanges!.containsKey('country_visit_id'),
        isFalse,
      );

      // No confirmation has been submitted automatically.
      expect(
        repository.receivedChanges!.containsKey('country_date_expansion'),
        isFalse,
      );

      // Close the dialog so the test finishes without a pending route.
      await tester.tap(find.byKey(const Key('cancelCountryExpansion')));

      await tester.pumpAndSettle();
    },
  );
  testWidgets('cancelling expansion does not submit another PATCH', (
    tester,
  ) async {
    final expansion = sampleDateExpansion();

    final repository = FakeCityVisitsRepository()
      ..expansionOnFirstUpdate = expansion;

    final cubit = await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    await tester.tap(find.byKey(const Key('cancelCountryExpansion')));

    await tester.pumpAndSettle();

    // Dialog closes.
    expect(find.text('Extend country visit dates?'), findsNothing);

    // The existing visit is not updated.
    expect(repository.updateCalls, 1);

    // No confirmation was sent.
    expect(
      repository.receivedChanges!.containsKey('country_date_expansion'),
      isFalse,
    );

    // The pending proposal was discarded.
    expect(cubit.state.pendingExpansion, isNull);

    expect(find.text('Edit City Visit'), findsOneWidget);
  });
  testWidgets(
    'confirming expansion repeats PATCH with exact backend proposal',
    (tester) async {
      final expansion = sampleDateExpansion();

      final repository = FakeCityVisitsRepository()
        ..expansionOnFirstUpdate = expansion;

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

      await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(find.text('Extend country visit dates?'), findsOneWidget);

      expect(repository.updateCalls, 1);

      await tester.tap(find.byKey(const Key('confirmCountryExpansion')));

      await tester.pumpAndSettle();

      // First PATCH + explicitly confirmed PATCH.
      expect(repository.updateCalls, 2);

      expect(repository.receivedVisitId, 'visit-1');

      expect(repository.receivedChanges!['ended_on'], DateTime(2024, 4, 1));

      expect(
        repository.receivedChanges!['ended_on_precision'],
        VisitDatePrecision.month,
      );

      // The existing association is preserved.
      expect(
        repository.receivedChanges!.containsKey('country_visit_id'),
        isFalse,
      );

      // The same proposal instance is submitted.
      expect(
        repository.receivedChanges!['country_date_expansion'],
        same(expansion),
      );
    },
  );
  testWidgets('stale expansion confirmation keeps the edit form open', (
    tester,
  ) async {
    final expansion = sampleDateExpansion();

    final repository = FakeCityVisitsRepository()
      ..expansionOnFirstUpdate = expansion;

    repository.updateHandler = () async {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'The country visit dates have changed.',
        statusCode: 409,
      );
    };

    final cubit = await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
      ),
    );

    await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(find.text('Extend country visit dates?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmCountryExpansion')));

    await tester.pumpAndSettle();

    // Initial PATCH + rejected confirmation.
    expect(repository.updateCalls, 2);

    // No automatic third request.
    expect(cubit.state.phase, EditCityVisitPhase.failure);

    expect(cubit.state.pendingExpansion, isNull);

    // The edit form remains available.
    expect(find.text('Edit City Visit'), findsOneWidget);

    // Error is presented to the user.
    expect(find.text('The country visit dates have changed.'), findsOneWidget);

    expect(find.text('Extend country visit dates?'), findsNothing);
  });
  testWidgets(
    'normal city visit update does not require expansion confirmation',
    (tester) async {
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

      await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(
        repository.receivedChanges!.containsKey('country_date_expansion'),
        isFalse,
      );

      expect(
        repository.receivedChanges!.containsKey('country_visit_id'),
        isFalse,
      );

      expect(find.text('Extend country visit dates?'), findsNothing);
    },
  );
  testWidgets('independent city visit without changes does not send PATCH', (
    tester,
  ) async {
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

    expect(repository.updateCalls, 0);

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    // No changes means no PATCH.
    expect(repository.updateCalls, 0);
  });
  testWidgets(
    'opening country visit options without selecting preserves independence',
    (tester) async {
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
        countryVisits: [makeCountryVisit(id: 'pt-visit-1', endMonth: 4)],
      );

      // Modify the city visit before scrolling to association options.
      await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

      await tapEditAssociationOption(tester, 'editCityAssociationExisting');

      final portugalVisitOption = find.byKey(
        const Key('editCountryVisitOption_pt-visit-1'),
      );

      await tester.scrollUntilVisible(
        portugalVisitOption,
        100,
        scrollable: find.byType(Scrollable).last,
      );

      await tester.pumpAndSettle();

      expect(portugalVisitOption, findsOneWidget);

      // The country visit is available, but not automatically selected.
      expect(
        find.byKey(const Key('editCountryVisitOption_pt-visit-1')),
        findsOneWidget,
      );

      // Save without selecting a country visit.
      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.receivedChanges, {
        'ended_on': DateTime(2024, 4, 1),
        'ended_on_precision': VisitDatePrecision.month,
      });

      // Opening the options must not create an association.
      expect(
        repository.receivedChanges!.containsKey('country_visit_id'),
        isFalse,
      );
    },
  );
  testWidgets(
    'explicitly linking a city visit sends selected country visit ID',
    (tester) async {
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
        countryVisits: [makeCountryVisit(id: 'pt-visit-1')],
      );

      // Initially, the city visit is independent.
      await tapEditAssociationOption(tester, 'editCityAssociationExisting');

      // Explicit user selection.
      await tapEditAssociationOption(
        tester,
        'editCountryVisitOption_pt-visit-1',
      );

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.receivedVisitId, 'visit-1');

      // Only the association changed.
      expect(repository.receivedChanges, {'country_visit_id': 'pt-visit-1'});

      // No date expansion was needed.
      expect(
        repository.receivedChanges!.containsKey('country_date_expansion'),
        isFalse,
      );
    },
  );
  testWidgets('removing an existing association sends country_visit_id null', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
        countryVisitId: 'pt-visit-1',
      ),
      countryVisits: [makeCountryVisit(id: 'pt-visit-1')],
    );

    await tapEditAssociationOption(tester, 'editCityAssociationNone');

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    expect(repository.receivedChanges, {'country_visit_id': null});
  });
  testWidgets(
    'editing dates preserves the existing country visit association',
    (tester) async {
      final repository = FakeCityVisitsRepository();

      await pumpSheet(
        tester,
        repository: repository,
        visit: makeVisit(
          startedOn: DateTime(2024, 1, 1),
          endedOn: DateTime(2024, 3, 1),
          startedOnPrecision: VisitDatePrecision.month,
          endedOnPrecision: VisitDatePrecision.month,
          countryVisitId: 'pt-visit-1',
        ),
        countryVisits: [makeCountryVisit(id: 'pt-visit-1', endMonth: 4)],
      );

      await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.receivedChanges, {
        'ended_on': DateTime(2024, 4, 1),
        'ended_on_precision': VisitDatePrecision.month,
      });

      // The association must not be removed or reassigned.
      expect(
        repository.receivedChanges!.containsKey('country_visit_id'),
        isFalse,
      );
    },
  );
  testWidgets(
    'changing an existing association sends the new country visit ID',
    (tester) async {
      final repository = FakeCityVisitsRepository();

      await pumpSheet(
        tester,
        repository: repository,
        visit: makeVisit(
          startedOn: DateTime(2024, 1, 1),
          endedOn: DateTime(2024, 3, 1),
          startedOnPrecision: VisitDatePrecision.month,
          endedOnPrecision: VisitDatePrecision.month,
          countryVisitId: 'pt-visit-1',
        ),
        countryVisits: [
          makeCountryVisit(id: 'pt-visit-1'),
          makeCountryVisit(id: 'pt-visit-2', endMonth: 4),
        ],
      );

      await tapEditAssociationOption(
        tester,
        'editCountryVisitOption_pt-visit-2',
      );

      await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);

      expect(repository.receivedChanges, {'country_visit_id': 'pt-visit-2'});
    },
  );
  testWidgets('country association options are filtered by city country', (
    tester,
  ) async {
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
      countryVisits: [
        makeCountryVisit(id: 'pt-visit-1', countryCode: 'PT'),
        makeCountryVisit(id: 'es-visit-1', countryCode: 'ES'),
      ],
    );

    await tapEditAssociationOption(tester, 'editCityAssociationExisting');

    final portugalOption = find.byKey(
      const Key('editCountryVisitOption_pt-visit-1'),
    );

    await tester.scrollUntilVisible(
      portugalOption,
      100,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.pumpAndSettle();

    expect(portugalOption, findsOneWidget);

    expect(
      find.byKey(const Key('editCountryVisitOption_es-visit-1')),
      findsNothing,
    );

    expect(repository.updateCalls, 0);
  });
  testWidgets('unavailable existing association is not silently removed', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository();

    await pumpSheet(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2024, 1, 1),
        endedOn: DateTime(2024, 3, 1),
        startedOnPrecision: VisitDatePrecision.month,
        endedOnPrecision: VisitDatePrecision.month,
        countryVisitId: 'pt-visit-missing',
      ),
      countryVisits: [makeCountryVisit(id: 'pt-visit-1')],
    );

    await tapEditAssociationOption(tester, 'editCityAssociationExisting');

    expect(
      find.textContaining(
        'The currently selected country visit is no longer available.',
      ),
      findsOneWidget,
    );

    // The user changes only the city dates.
    // No association change is requested.
    //
    // Scroll back to the date fields if necessary.
    await tester.scrollUntilVisible(
      find.byKey(const Key('editCityVisitEndDate')),
      -150,
      scrollable: find.byType(Scrollable).last,
    );

    await changeCityVisitEndMonth(tester, monthLabel: 'April 2024');

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);

    expect(
      repository.receivedChanges!.containsKey('country_visit_id'),
      isFalse,
    );
  });
}
